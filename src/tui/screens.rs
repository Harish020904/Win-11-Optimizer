//! Screen rendering and input handling

use crate::app::WizardState;
use crate::core::Layer;
use crate::tui::{app_state::LogLevel, theme::Theme, widgets, TuiState};
use anyhow::Result;
use crossterm::event::KeyCode;
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout},
    style::Modifier,
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

/// Draw the current screen
pub fn draw(frame: &mut Frame, state: &TuiState) {
    match &state.screen {
        WizardState::Welcome => draw_welcome(frame, state),
        WizardState::LayerSelect => draw_layer_select(frame, state),
        WizardState::Preview => draw_preview(frame, state),
        WizardState::Consent => draw_consent(frame, state),
        WizardState::Applying => draw_applying(frame, state),
        WizardState::Verifying => draw_verifying(frame, state),
        WizardState::Complete => draw_complete(frame, state),
        WizardState::StatusDashboard => draw_status(frame, state),
        WizardState::Error(msg) => draw_error(frame, msg),
        _ => draw_welcome(frame, state),
    }
}

/// Handle key input for current screen
pub async fn handle_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    match &state.screen {
        WizardState::Welcome => handle_welcome_key(state, key),
        WizardState::LayerSelect => handle_layer_select_key(state, key),
        WizardState::Preview => handle_preview_key(state, key),
        WizardState::Consent => handle_consent_key(state, key),
        WizardState::Complete => handle_complete_key(state, key),
        WizardState::StatusDashboard => handle_status_key(state, key),
        WizardState::Error(_) => handle_error_key(state, key),
        _ => Ok(false),
    }
}

// ============================================================================
// Welcome Screen
// ============================================================================

fn draw_welcome(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();

    // Main layout: Top header | Content with sidebar | Bottom help
    let main_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(8),  // Header with 3D ASCII logo (6 + 1 + 1)
            Constraint::Min(10),    // Main content area
            Constraint::Length(1),  // Help bar
        ])
        .split(area);

    // Header
    widgets::draw_tech_header(frame, main_chunks[0], "2.0");

    // Content area: Left sidebar | Right content
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .margin(1)
        .constraints([
            Constraint::Length(30),  // Sidebar
            Constraint::Min(40),     // Main content
        ])
        .split(main_chunks[1]);

    // Left sidebar with layers
    let layers = vec![
        ("Minimal", "🟢", false),
        ("Moderate", "🔵", false),
        ("Ultimate", "🟡", false),
        ("GodMode", "🔴", false),
    ];
    widgets::draw_sidebar(frame, content_chunks[0], "LAYERS", &layers, false);

    // Right content area: Welcome info | System info | Cleanup | Actions
    let right_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12),  // Welcome text
            Constraint::Length(10),  // System info
            Constraint::Length(10),  // Cleanup estimate
            Constraint::Min(3),      // Actions
        ])
        .split(content_chunks[1]);

    // Welcome content
    let welcome_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border_focus())
        .title(Span::styled(" WELCOME ", Theme::title()));
    let welcome_inner = welcome_block.inner(right_chunks[0]);
    frame.render_widget(welcome_block, right_chunks[0]);

    let welcome_text = vec![
        Line::from(""),
        Line::from(Span::styled(
            "Progressive System Optimization Framework",
            Theme::title(),
        )),
        Line::from(""),
        Line::from(vec![
            Span::styled("  🟢 Minimal   ", Theme::success()),
            Span::styled("→ Reduce telemetry, bloat & UI clutter", Theme::dim()),
        ]),
        Line::from(vec![
            Span::styled("  🔵 Moderate  ", Theme::info()),
            Span::styled("→ Developer workstation optimization", Theme::dim()),
        ]),
        Line::from(vec![
            Span::styled("  🟡 Ultimate  ", Theme::warning()),
            Span::styled("→ Enterprise hardening & lockdown", Theme::dim()),
        ]),
        Line::from(vec![
            Span::styled("  🔴 GodMode   ", Theme::error()),
            Span::styled("→ Maximum system control", Theme::dim()),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("⚠ ", Theme::warning()),
            Span::styled("TEST IN VM • BACKUP SYSTEM", Theme::warning().add_modifier(Modifier::BOLD)),
        ]),
    ];

    let content = Paragraph::new(welcome_text);
    frame.render_widget(content, welcome_inner);

    // System info panel
    widgets::draw_system_info(frame, right_chunks[1], &state.system_info);

    // Cleanup estimate panel
    widgets::draw_cleanup_estimate(frame, right_chunks[2], &state.cleanup_estimate);

    // Actions block
    let actions_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border())
        .title(Span::styled(" ACTIONS ", Theme::title()));
    let actions_inner = actions_block.inner(right_chunks[3]);
    frame.render_widget(actions_block, right_chunks[3]);

    let buttons = [
        ("▶ Start Wizard", 0),
        ("📊 View Status", 1),
        ("❌ Exit", 2),
    ];
    
    let action_text: Vec<Line> = buttons
        .iter()
        .enumerate()
        .map(|(i, (label, _))| {
            let style = if state.selected_index == i {
                Theme::selected()
            } else {
                Theme::normal()
            };
            let prefix = if state.selected_index == i { "▶ " } else { "  " };
            Line::from(vec![
                Span::styled(prefix, style),
                Span::styled(*label, style),
            ])
        })
        .collect();

    let actions = Paragraph::new(action_text);
    frame.render_widget(actions, actions_inner);

    // Help bar
    widgets::draw_help(
        frame,
        main_chunks[2],
        &[("↑/↓", "Navigate"), ("Enter", "Select"), ("q", "Quit")],
    );
}

fn handle_welcome_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    match key {
        KeyCode::Up => state.select_up(3),
        KeyCode::Down => state.select_down(3),
        KeyCode::Enter => match state.selected_index {
            0 => state.next_screen(), // Start wizard
            1 => state.screen = WizardState::StatusDashboard,
            2 => return Ok(true), // Exit
            _ => {}
        },
        KeyCode::Char('q') => return Ok(true),
        _ => {}
    }
    Ok(false)
}

// ============================================================================
// Layer Selection Screen
// ============================================================================

fn draw_layer_select(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();

    // Main layout
    let main_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(8),  // Header with 3D logo
            Constraint::Min(10),    // Content
            Constraint::Length(1),  // Help
        ])
        .split(area);

    // Header
    widgets::draw_tech_header(frame, main_chunks[0], "2.0");

    // Content: Sidebar | Main
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .margin(1)
        .constraints([
            Constraint::Length(30),  // Sidebar
            Constraint::Min(40),     // Main content
        ])
        .split(main_chunks[1]);

    // Left sidebar with selectable layers
    let layers = state.available_layers();
    let applied = state.ctx.applied_layers();
    
    let sidebar_items: Vec<(&str, &str, bool)> = layers
        .iter()
        .enumerate()
        .map(|(i, layer)| {
            let is_selected = i == state.selected_index;
            let icon = match layer {
                Layer::Minimal => "🟢",
                Layer::Moderate => "🔵",
                Layer::Ultimate => "🟡",
                Layer::GodMode => "🔴",
            };
            (layer.display_name(), icon, is_selected)
        })
        .collect();

    widgets::draw_sidebar(frame, content_chunks[0], "SELECT LAYER", &sidebar_items, true);

    // Right side: Layer details
    if let Some(current_layer) = layers.get(state.selected_index) {
        let is_applied = applied.contains(current_layer);
        let can_apply = current_layer.can_apply(&applied);
        
        let right_chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(8),   // Layer info
                Constraint::Min(8),      // Details
                Constraint::Length(6),   // Status/Actions
            ])
            .split(content_chunks[1]);

        // Layer info block
        let info_block = Block::default()
            .borders(Borders::ALL)
            .border_style(Theme::border_focus())
            .title(Span::styled(
                format!(" {} LAYER ", current_layer.display_name().to_uppercase()),
                Theme::title(),
            ));
        let info_inner = info_block.inner(right_chunks[0]);
        frame.render_widget(info_block, right_chunks[0]);

        let risk = current_layer.risk_level();
        let info_text = vec![
            Line::from(""),
            Line::from(vec![
                Span::styled("Risk Level:    ", Theme::dim()),
                Span::styled(format!("{}", risk), Theme::risk_style(&risk).add_modifier(Modifier::BOLD)),
            ]),
            Line::from(vec![
                Span::styled("Reversible:    ", Theme::dim()),
                Span::styled(
                    if current_layer.is_reversible() { "Yes" } else { "Partial" },
                    if current_layer.is_reversible() { Theme::success() } else { Theme::warning() }
                ),
            ]),
            Line::from(vec![
                Span::styled("Status:        ", Theme::dim()),
                Span::styled(
                    if is_applied { "APPLIED" } else if can_apply { "AVAILABLE" } else { "LOCKED" },
                    if is_applied { Theme::success() } 
                    else if can_apply { Theme::info() } 
                    else { Theme::dim() }
                ),
            ]),
        ];

        let info = Paragraph::new(info_text);
        frame.render_widget(info, info_inner);

        // Details block
        let details_block = Block::default()
            .borders(Borders::ALL)
            .border_style(Theme::border())
            .title(Span::styled(" DESCRIPTION ", Theme::title()));
        let details_inner = details_block.inner(right_chunks[1]);
        frame.render_widget(details_block, right_chunks[1]);

        let details_text = vec![
            Line::from(""),
            Line::from(Span::styled(current_layer.description(), Theme::normal())),
            Line::from(""),
            Line::from(Span::styled("This layer will:", Theme::dim())),
            Line::from(Span::styled("  • Configure system settings", Theme::dim())),
            Line::from(Span::styled("  • Modify services and tasks", Theme::dim())),
            Line::from(Span::styled("  • Apply security policies", Theme::dim())),
            Line::from(""),
            Line::from(vec![
                Span::styled("⚠ ", Theme::warning()),
                Span::styled("Review changes before applying", Theme::warning()),
            ]),
        ];

        let details = Paragraph::new(details_text).wrap(Wrap { trim: false });
        frame.render_widget(details, details_inner);

        // Actions block
        let actions_block = Block::default()
            .borders(Borders::ALL)
            .border_style(Theme::border())
            .title(Span::styled(" ACTIONS ", Theme::title()));
        let actions_inner = actions_block.inner(right_chunks[2]);
        frame.render_widget(actions_block, right_chunks[2]);

        let action_text = if is_applied {
            vec![
                Line::from(""),
                Line::from(Span::styled("✓ This layer is already applied", Theme::success())),
                Line::from(""),
                Line::from(Span::styled("Press [Esc] to go back", Theme::dim())),
            ]
        } else if !can_apply {
            vec![
                Line::from(""),
                Line::from(Span::styled("⚠ Prerequisites not met", Theme::warning())),
                Line::from(""),
                Line::from(Span::styled("Apply lower layers first", Theme::dim())),
            ]
        } else {
            vec![
                Line::from(""),
                Line::from(Span::styled("▶ Press [Enter] to continue", Theme::highlight().add_modifier(Modifier::BOLD))),
                Line::from(Span::styled("  Press [Esc] to go back", Theme::dim())),
            ]
        };

        let actions = Paragraph::new(action_text);
        frame.render_widget(actions, actions_inner);
    }

    // Help
    widgets::draw_help(
        frame,
        main_chunks[2],
        &[
            ("↑/↓", "Navigate"),
            ("Enter", "Select"),
            ("Esc", "Back"),
            ("q", "Quit"),
        ],
    );
}

fn handle_layer_select_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    let layers = state.available_layers();
    let applied = state.ctx.applied_layers();

    match key {
        KeyCode::Up => state.select_up(layers.len()),
        KeyCode::Down => state.select_down(layers.len()),
        KeyCode::Enter => {
            if let Some(layer) = layers.get(state.selected_index) {
                if layer.can_apply(&applied) && !applied.contains(layer) {
                    state.set_selected_layer(*layer);
                    state.next_screen();
                }
            }
        }
        KeyCode::Esc => state.prev_screen(),
        _ => {}
    }
    Ok(false)
}

// ============================================================================
// Preview Screen
// ============================================================================

fn draw_preview(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(10),
            Constraint::Length(1),
        ])
        .split(area);

    let layer = state.selected_layer().unwrap_or(Layer::Minimal);

    // Title
    let title = Paragraph::new(vec![
        Line::from(Span::styled(
            format!("Preview: {} Layer", layer.display_name()),
            Theme::title(),
        )),
        Line::from(Span::styled("Step 2/5", Theme::dim())),
    ])
    .alignment(Alignment::Center);
    frame.render_widget(title, chunks[0]);

    // Preview content
    let modules = state.ctx.get_modules(layer).unwrap_or_default();

    let content_block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border())
        .title(" Changes to be made ");

    let content_area = content_block.inner(chunks[1]);
    frame.render_widget(content_block, chunks[1]);

    let mut lines = vec![Line::from("")];
    for module in &modules {
        lines.push(Line::from(vec![
            Span::styled("• ", Theme::normal()),
            Span::styled(&module.title, Theme::highlight()),
        ]));
        lines.push(Line::from(vec![
            Span::raw("  "),
            Span::styled(&module.summary, Theme::dim()),
        ]));
        lines.push(Line::from(""));
    }

    let content = Paragraph::new(lines).wrap(Wrap { trim: true });
    frame.render_widget(content, content_area);

    // Help
    widgets::draw_help(
        frame,
        chunks[2],
        &[("Enter", "Continue"), ("Esc", "Back"), ("q", "Quit")],
    );
}

fn handle_preview_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    match key {
        KeyCode::Enter => state.next_screen(),
        KeyCode::Esc => state.prev_screen(),
        _ => {}
    }
    Ok(false)
}

// ============================================================================
// Consent Screen
// ============================================================================

fn draw_consent(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();
    let layer = state.selected_layer().unwrap_or(Layer::Minimal);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(8),
            Constraint::Length(3),
            Constraint::Length(1),
        ])
        .split(area);

    // Title
    let title = Paragraph::new(vec![
        Line::from(Span::styled("Confirm Application", Theme::title())),
        Line::from(Span::styled("Step 3/5", Theme::dim())),
    ])
    .alignment(Alignment::Center);
    frame.render_widget(title, chunks[0]);

    // Consent message
    let risk = layer.risk_level();
    let consent_text = vec![
        Line::from(""),
        Line::from(vec![
            Span::styled("You are about to apply the ", Theme::normal()),
            Span::styled(layer.display_name(), Theme::highlight()),
            Span::styled(" layer.", Theme::normal()),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("Risk Level: ", Theme::normal()),
            Span::styled(format!("{}", risk), Theme::risk_style(&risk)),
        ]),
        Line::from(""),
        Line::from(Span::styled(
            "A system restore point will be created before applying changes.",
            Theme::dim(),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "Do you want to proceed?",
            Theme::warning(),
        )),
    ];

    let consent = Paragraph::new(consent_text)
        .block(Block::default().borders(Borders::ALL).border_style(Theme::border()))
        .alignment(Alignment::Center);
    frame.render_widget(consent, chunks[1]);

    // Buttons
    let button_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(33),
            Constraint::Percentage(34),
            Constraint::Percentage(33),
        ])
        .split(chunks[2]);

    widgets::draw_button(frame, button_chunks[0], "✓ Apply", state.selected_index == 0);
    widgets::draw_button(frame, button_chunks[2], "✗ Cancel", state.selected_index == 1);

    // Help
    widgets::draw_help(
        frame,
        chunks[3],
        &[("←/→", "Select"), ("Enter", "Confirm")],
    );
}

fn handle_consent_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    match key {
        KeyCode::Left | KeyCode::Right => {
            state.selected_index = if state.selected_index == 0 { 1 } else { 0 };
        }
        KeyCode::Enter => {
            if state.selected_index == 0 {
                // Apply
                state.logs.clear();
                state.add_log(LogLevel::Info, "Starting optimization...");
                state.next_screen();
            } else {
                // Cancel
                state.prev_screen();
            }
        }
        KeyCode::Esc => state.prev_screen(),
        _ => {}
    }
    Ok(false)
}

// ============================================================================
// Applying Screen
// ============================================================================

fn draw_applying(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Length(3),
            Constraint::Length(3),
            Constraint::Min(8),
            Constraint::Length(1),
        ])
        .split(area);

    let layer = state.selected_layer().unwrap_or(Layer::Minimal);

    // Title
    let title = Paragraph::new(vec![
        Line::from(Span::styled(
            format!("Applying {} Layer", layer.display_name()),
            Theme::title(),
        )),
        Line::from(Span::styled("Step 4/5", Theme::dim())),
    ])
    .alignment(Alignment::Center);
    frame.render_widget(title, chunks[0]);

    // Progress
    if let Some(progress) = &state.progress {
        widgets::draw_progress(
            frame,
            chunks[1],
            &progress.description,
            progress.percent,
        );
    }

    // Logs
    widgets::draw_log_panel(frame, chunks[2], "Log", &state.logs);

    // Help
    widgets::draw_help(frame, chunks[3], &[("Please wait...", "")]);
}

// ============================================================================
// Verifying Screen
// ============================================================================

fn draw_verifying(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(10),
            Constraint::Length(1),
        ])
        .split(area);

    // Title
    let title = Paragraph::new(vec![
        Line::from(Span::styled("Verifying Changes", Theme::title())),
        Line::from(Span::styled("Step 5/5", Theme::dim())),
    ])
    .alignment(Alignment::Center);
    frame.render_widget(title, chunks[0]);

    // Logs
    widgets::draw_log_panel(frame, chunks[1], "Verification Log", &state.logs);

    // Help
    widgets::draw_help(frame, chunks[2], &[("Verifying...", "")]);
}

// ============================================================================
// Complete Screen
// ============================================================================

fn draw_complete(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();
    let layer = state.selected_layer().unwrap_or(Layer::Minimal);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(8),
            Constraint::Length(3),
            Constraint::Length(1),
        ])
        .split(area);

    // Title
    let title = Paragraph::new(vec![
        Line::from(Span::styled("✓ Optimization Complete!", Theme::success())),
    ])
    .alignment(Alignment::Center);
    frame.render_widget(title, chunks[0]);

    // Summary
    let summary = vec![
        Line::from(""),
        Line::from(vec![
            Span::styled("Layer Applied: ", Theme::normal()),
            Span::styled(layer.display_name(), Theme::highlight()),
        ]),
        Line::from(""),
        Line::from(Span::styled(
            "Recommendations:",
            Theme::normal(),
        )),
        Line::from(Span::styled(
            "  • Observe system for 24-48 hours",
            Theme::dim(),
        )),
        Line::from(Span::styled(
            "  • Check Event Viewer for errors",
            Theme::dim(),
        )),
        Line::from(Span::styled(
            "  • Run Windows Update to ensure it still works",
            Theme::dim(),
        )),
        Line::from(""),
        Line::from(Span::styled(
            "You can rollback changes from the Status Dashboard.",
            Theme::dim(),
        )),
    ];

    let content = Paragraph::new(summary)
        .block(Block::default().borders(Borders::ALL).border_style(Theme::border()))
        .alignment(Alignment::Center);
    frame.render_widget(content, chunks[1]);

    // Buttons
    let button_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(50),
            Constraint::Percentage(50),
        ])
        .split(chunks[2]);

    widgets::draw_button(frame, button_chunks[0], "📊 View Status", state.selected_index == 0);
    widgets::draw_button(frame, button_chunks[1], "🏠 Home", state.selected_index == 1);

    // Help
    widgets::draw_help(
        frame,
        chunks[3],
        &[("←/→", "Select"), ("Enter", "Confirm")],
    );
}

fn handle_complete_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    match key {
        KeyCode::Left | KeyCode::Right => {
            state.selected_index = if state.selected_index == 0 { 1 } else { 0 };
        }
        KeyCode::Enter => {
            if state.selected_index == 0 {
                state.screen = WizardState::StatusDashboard;
            } else {
                state.screen = WizardState::Welcome;
            }
            state.selected_index = 0;
        }
        _ => {}
    }
    Ok(false)
}

// ============================================================================
// Status Dashboard
// ============================================================================

fn draw_status(frame: &mut Frame, state: &TuiState) {
    let area = frame.size();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(2)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(10),
            Constraint::Length(1),
        ])
        .split(area);

    // Title
    let title = Paragraph::new(vec![
        Line::from(Span::styled("System Status Dashboard", Theme::title())),
    ])
    .alignment(Alignment::Center);
    frame.render_widget(title, chunks[0]);

    // Status content
    let applied = state.ctx.applied_layers();

    let mut lines = vec![Line::from("")];

    if applied.is_empty() {
        lines.push(Line::from(Span::styled(
            "No optimization layers currently applied.",
            Theme::dim(),
        )));
    } else {
        lines.push(Line::from(Span::styled("Applied Layers:", Theme::normal())));
        lines.push(Line::from(""));

        for layer in &applied {
            let info = state.ctx.state.get_layer_info(*layer);
            let time = info
                .as_ref()
                .map(|i| i.applied_at.format("%Y-%m-%d %H:%M").to_string())
                .unwrap_or_else(|| "Unknown".to_string());

            lines.push(Line::from(vec![
                Span::styled("  ✓ ", Theme::success()),
                Span::styled(layer.display_name(), Theme::highlight()),
                Span::styled(format!(" - Applied at {}", time), Theme::dim()),
            ]));
        }
    }

    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled("Available Actions:", Theme::normal())));
    lines.push(Line::from(Span::styled(
        "  • Press 'r' to rollback the last layer",
        Theme::dim(),
    )));
    lines.push(Line::from(Span::styled(
        "  • Press 'h' to return home",
        Theme::dim(),
    )));

    let content = Paragraph::new(lines)
        .block(Block::default().borders(Borders::ALL).border_style(Theme::border()));
    frame.render_widget(content, chunks[1]);

    // Help
    widgets::draw_help(
        frame,
        chunks[2],
        &[("r", "Rollback"), ("h", "Home"), ("q", "Quit")],
    );
}

fn handle_status_key(state: &mut TuiState, key: KeyCode) -> Result<bool> {
    match key {
        KeyCode::Char('r') => {
            state.screen = WizardState::RollbackConfirm;
        }
        KeyCode::Char('h') | KeyCode::Esc => {
            state.screen = WizardState::Welcome;
            state.selected_index = 0;
        }
        _ => {}
    }
    Ok(false)
}

// ============================================================================
// Error Screen
// ============================================================================

fn draw_error(frame: &mut Frame, message: &str) {
    let area = widgets::centered_rect(60, 30, frame.size());

    let content = Paragraph::new(vec![
        Line::from(Span::styled("Error", Theme::error())),
        Line::from(""),
        Line::from(Span::styled(message, Theme::normal())),
        Line::from(""),
        Line::from(Span::styled("Press any key to continue...", Theme::dim())),
    ])
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Theme::error())
            .title(" Error "),
    )
    .alignment(Alignment::Center);

    frame.render_widget(content, area);
}

fn handle_error_key(state: &mut TuiState, _key: KeyCode) -> Result<bool> {
    state.screen = WizardState::Welcome;
    state.selected_index = 0;
    Ok(false)
}
