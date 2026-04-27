use ratatui::{
    layout::{Alignment, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph, Wrap},
    Frame,
};

use crate::{app::AppState, theme};

pub fn render(frame: &mut Frame<'_>, area: Rect, app: &AppState, layer: &str) {
    let failures = app
        .tweak_states
        .iter()
        .filter(|t| matches!(t.status, crate::app::TweakStatus::Failed))
        .count();
    let text = vec![
        Line::from(Span::styled(
            format!("Rollback {layer}"),
            Style::default()
                .fg(theme::ACCENT_YELLOW)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from("Press Enter to start rollback for the selected layer."),
        Line::from("Press Esc to return to the main menu."),
        Line::from(""),
        Line::from(format!(
            "Completed rollback steps: {}",
            app.tweak_states.len()
        )),
        Line::from(format!("Failures: {failures}")),
    ];

    let block = Block::default()
        .title("Rollback")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_YELLOW))
        .style(theme::panel());
    frame.render_widget(
        Paragraph::new(text)
            .block(block)
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true }),
        area,
    );
}
