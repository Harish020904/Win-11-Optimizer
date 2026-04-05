//! Terminal User Interface with Ratatui

mod app_state;
mod screens;
mod theme;
mod widgets;

use crate::app::AppContext;
use anyhow::Result;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use std::io;

pub use app_state::TuiState;

/// Run the TUI application
pub async fn run(ctx: AppContext) -> Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create TUI state
    let mut state = TuiState::new(ctx);

    // Main loop
    let result = run_loop(&mut terminal, &mut state).await;

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    result
}

/// Main TUI event loop
async fn run_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    state: &mut TuiState,
) -> Result<()> {
    loop {
        // Draw current screen
        terminal.draw(|frame| {
            screens::draw(frame, state);
        })?;

        // Handle events
        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    // Global quit handling
                    if key.code == KeyCode::Char('q') && state.can_quit() {
                        break;
                    }

                    // Handle key in current screen
                    if screens::handle_key(state, key.code).await? {
                        // Screen indicated we should exit
                        break;
                    }
                }
            }
        }

        // Check if we should exit
        if state.should_exit {
            break;
        }
    }

    Ok(())
}
