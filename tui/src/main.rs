mod app;
mod ipc;
mod theme;
mod ui;

use std::{error::Error, io, time::Duration};

use app::{AppState, Screen, TweakStatus};
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ipc::{ConsentDecision, IpcCommand, IpcEvent};
use ratatui::{backend::CrosstermBackend, Terminal};
use tokio::{process::Child, sync::mpsc, time};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let (mut child, mut reader) = ipc::spawn_backend().await?;

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let (event_tx, mut event_rx) = mpsc::unbounded_channel();
    tokio::spawn(async move {
        loop {
            match ipc::read_event(&mut reader).await {
                Ok(event) => {
                    if event_tx.send(Ok(event)).is_err() {
                        break;
                    }
                }
                Err(err) => {
                    let _ = event_tx.send(Err(err));
                    break;
                }
            }
        }
    });

    let mut app = AppState::default();
    let _ = ipc::send_command(&mut child, IpcCommand::GetStatus).await;
    let _ = ipc::send_command(&mut child, IpcCommand::GetState).await;

    let mut spinner_tick = time::interval(Duration::from_millis(80));
    let mut status_tick = time::interval(Duration::from_secs(2));

    loop {
        terminal.draw(|frame| ui::render(frame, &app))?;

        while event::poll(Duration::from_millis(0))? {
            if let Event::Key(key) = event::read()? {
                handle_key(&mut app, key, &mut child).await;
            }
        }

        if app.should_quit {
            break;
        }

        if let Some(status) = child.try_wait()? {
            app.screen = Screen::Error(format!("PowerShell backend exited with {status}"));
        }

        tokio::select! {
            biased;
            Some(event) = event_rx.recv() => {
                match event {
                    Ok(event) => handle_ipc_event(&mut app, event, &mut child).await,
                    Err(err) => app.screen = Screen::Error(err.to_string()),
                }
            }
            _ = status_tick.tick() => {
                if !app.awaiting_consent() && !matches!(app.screen, Screen::LayerProgress(_)) {
                    let _ = ipc::send_command(&mut child, IpcCommand::GetStatus).await;
                }
            }
            _ = spinner_tick.tick() => {
                app.spinner_index = app.spinner_index.wrapping_add(1);
            }
            _ = time::sleep(Duration::from_millis(20)) => {}
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    let _ = child.kill().await;
    Ok(())
}

async fn handle_key(app: &mut AppState, key: KeyEvent, child: &mut Child) {
    if key.code == KeyCode::Char('q') || key.code == KeyCode::Char('Q') {
        if app.awaiting_consent() {
            let _ = ipc::send_command(
                child,
                IpcCommand::Consent {
                    decision: ConsentDecision::Quit,
                },
            )
            .await;
        }
        app.should_quit = true;
        return;
    }

    match app.screen.clone() {
        Screen::MainMenu => handle_menu_key(app, key, child).await,
        Screen::DisclaimerCard(data) => match key.code {
            KeyCode::Char('y') | KeyCode::Char('Y') => {
                send_consent(app, child, ConsentDecision::Apply).await;
            }
            KeyCode::Char('n') | KeyCode::Char('N') => {
                send_consent(app, child, ConsentDecision::Skip).await;
            }
            KeyCode::Char('d') | KeyCode::Char('D') => {
                app.dry_run = true;
                send_consent(app, child, ConsentDecision::DryRun).await;
            }
            KeyCode::Char('a') | KeyCode::Char('A') => {
                if data.layer.eq_ignore_ascii_case("GODMODE")
                    || data.layer.eq_ignore_ascii_case("GOD MODE")
                {
                    app.godmode_input_buf.clear();
                    app.screen = Screen::GodModeConfirmInput;
                } else {
                    app.global_run_all = true;
                    send_consent(app, child, ConsentDecision::RunAll).await;
                }
            }
            _ => {}
        },
        Screen::GodModeConfirmInput => handle_godmode_key(app, key, child).await,
        Screen::RollbackConfirm(layer) => match key.code {
            KeyCode::Enter => {
                app.begin_layer(format!("ROLLBACK {layer}"));
                send(app, child, IpcCommand::RollbackLayer { layer }).await;
            }
            KeyCode::Esc => app.screen = Screen::MainMenu,
            _ => {}
        },
        Screen::VerifyResults | Screen::StatusDetail | Screen::Error(_) => {
            if matches!(key.code, KeyCode::Esc | KeyCode::Enter) {
                app.screen = Screen::MainMenu;
            }
        }
        Screen::LayerProgress(_) => {}
    }
}

async fn handle_menu_key(app: &mut AppState, key: KeyEvent, child: &mut Child) {
    match key.code {
        KeyCode::Up => app.select_up(),
        KeyCode::Down => app.select_down(),
        KeyCode::Char('d') | KeyCode::Char('D') => app.dry_run = !app.dry_run,
        KeyCode::Char('s') | KeyCode::Char('S') => app.screen = Screen::StatusDetail,
        KeyCode::Enter => match app.menu_selected {
            0..=3 => {
                if let Some(layer) = AppState::layer_for_menu_index(app.menu_selected) {
                    let layer = layer.to_string();
                    app.begin_layer(layer.clone());
                    send(
                        app,
                        child,
                        IpcCommand::ApplyLayer {
                            layer,
                            dry_run: app.dry_run,
                        },
                    )
                    .await;
                }
            }
            4 => {
                let layer = app
                    .applied_layers
                    .last()
                    .cloned()
                    .unwrap_or_else(|| "MINIMAL".to_string());
                app.screen = Screen::RollbackConfirm(layer.to_ascii_uppercase());
            }
            5 => {
                app.verify_results.clear();
                app.screen = Screen::VerifyResults;
                send(app, child, IpcCommand::VerifySystem).await;
            }
            6 => {
                app.begin_layer("SNAPSHOT");
                send(app, child, IpcCommand::Snapshot).await;
            }
            _ => app.should_quit = true,
        },
        _ => {}
    }
}

async fn handle_godmode_key(app: &mut AppState, key: KeyEvent, child: &mut Child) {
    match key.code {
        KeyCode::Esc => {
            send_consent(app, child, ConsentDecision::Skip).await;
            app.godmode_input_buf.clear();
        }
        KeyCode::Backspace => {
            app.godmode_input_buf.pop();
        }
        KeyCode::Enter => {
            if app.godmode_input_buf == "GODMODE" {
                app.global_run_all = true;
                send_consent(app, child, ConsentDecision::RunAll).await;
                app.godmode_input_buf.clear();
            } else {
                app.push_log("GODMODE confirmation did not match");
                app.godmode_input_buf.clear();
            }
        }
        KeyCode::Char(ch) => {
            if app.godmode_input_buf.len() < 16 {
                app.godmode_input_buf.push(ch.to_ascii_uppercase());
            }
        }
        _ => {}
    }
}

async fn send_consent(app: &mut AppState, child: &mut Child, decision: ConsentDecision) {
    let layer = app
        .current_layer
        .clone()
        .unwrap_or_else(|| "UNKNOWN".to_string());
    app.screen = Screen::LayerProgress(layer);
    send(app, child, IpcCommand::Consent { decision }).await;
}

async fn send(app: &mut AppState, child: &mut Child, command: IpcCommand) {
    if let Err(err) = ipc::send_command(child, command).await {
        app.screen = Screen::Error(err.to_string());
    }
}

async fn handle_ipc_event(app: &mut AppState, event: IpcEvent, child: &mut Child) {
    match event {
        IpcEvent::Progress {
            tweak_id,
            tweak_name,
            message,
            state,
        } => {
            let status = match state.as_str() {
                "done" => TweakStatus::Done,
                "failed" => TweakStatus::Failed,
                "skipped" => TweakStatus::Skipped,
                "in_progress" => TweakStatus::InProgress,
                _ => TweakStatus::Pending,
            };
            let name = if tweak_name.is_empty() {
                message.clone()
            } else {
                tweak_name
            };
            app.update_tweak(tweak_id, name, status, message.clone());
            app.push_log(message);
        }
        IpcEvent::Done { layer, passed } => {
            app.push_log(format!(
                "{layer} completed: {}",
                if passed { "passed" } else { "failed" }
            ));
            if layer == "VERIFY" {
                app.screen = Screen::VerifyResults;
            } else {
                app.screen = Screen::MainMenu;
            }
            let _ = ipc::send_command(child, IpcCommand::GetStatus).await;
        }
        IpcEvent::Error {
            tweak_id,
            tweak_name,
            message,
        } => {
            let name = if tweak_name.is_empty() {
                "Backend error".to_string()
            } else {
                tweak_name
            };
            app.update_tweak(tweak_id, name, TweakStatus::Failed, message.clone());
            app.last_error = Some(message.clone());
            app.push_log(message);
        }
        IpcEvent::ConsentRequired(data) => app.set_disclaimer(data),
        IpcEvent::Status { metrics } => app.set_metrics(metrics),
        IpcEvent::Verify(result) => app.verify_results.push(result),
        IpcEvent::State { state } => {
            if let Some(layers) = state.get("AppliedLayers").and_then(|v| v.as_array()) {
                app.applied_layers = layers
                    .iter()
                    .filter_map(|v| v.as_str().map(ToString::to_string))
                    .collect();
            } else if let Some(layers) = state.get("layers").and_then(|v| v.as_object()) {
                app.applied_layers = layers.keys().cloned().collect();
            }
        }
        IpcEvent::Log { message } => app.push_log(message),
    }
}
