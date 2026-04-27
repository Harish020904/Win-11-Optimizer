use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
    Frame,
};

use crate::{app::AppState, theme};

#[derive(Debug, Clone, Copy)]
pub struct RootChunks {
    pub header: Rect,
    pub body: Rect,
    pub status_bar: Rect,
}

#[derive(Debug, Clone, Copy)]
pub struct BodyChunks {
    pub main: Rect,
    pub status: Rect,
}

pub fn root_chunks(area: Rect) -> RootChunks {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(3),
            Constraint::Length(1),
        ])
        .split(area);

    RootChunks {
        header: chunks[0],
        body: chunks[1],
        status_bar: chunks[2],
    }
}

pub fn body_chunks(area: Rect) -> BodyChunks {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(65), Constraint::Percentage(35)])
        .split(area);
    BodyChunks {
        main: chunks[0],
        status: chunks[1],
    }
}

pub fn render_header(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let badges = [
        ("MINIMAL", "MINIMAL"),
        ("MOD", "MODERATE"),
        ("ULT", "ULTIMATE"),
        ("GOD", "GODMODE"),
    ]
    .iter()
    .map(|(label_layer, state_layer)| {
        let applied = app
            .applied_layers
            .iter()
            .any(|applied| applied.eq_ignore_ascii_case(state_layer));
        let label = if applied {
            format!("[{label_layer}✓]")
        } else {
            format!("[{label_layer} ]")
        };
        Span::styled(label, Style::default().fg(theme::layer_color(state_layer)))
    })
    .collect::<Vec<_>>();

    let mut spans = vec![
        Span::styled(
            "WIN11 OPTIMIZER v2.0",
            Style::default()
                .fg(theme::FG_PRIMARY)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw("  "),
    ];
    spans.extend(badges);
    if app.dry_run {
        spans.push(Span::styled(
            "  DRY-RUN",
            Style::default().fg(theme::ACCENT_CYAN),
        ));
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(ratatui::widgets::BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_BLUE))
        .style(theme::panel());
    frame.render_widget(Paragraph::new(Line::from(spans)).block(block), area);
}

pub fn render_status_bar(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let text = if app.awaiting_consent() {
        "[Y] Apply  [N] Skip  [A] Run All  [D] Dry-run  [Q] Quit"
    } else {
        "[↑↓] Navigate  [Enter] Select  [D] Dry-run  [Q] Quit"
    };
    let paragraph = Paragraph::new(text).style(
        Style::default()
            .fg(theme::ACCENT_BLUE)
            .bg(theme::BG_PRIMARY),
    );
    frame.render_widget(paragraph, area);
}
