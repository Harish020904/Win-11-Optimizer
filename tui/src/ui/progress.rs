use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Gauge, List, ListItem, Paragraph},
    Frame,
};

use crate::{
    app::{AppState, TweakStatus},
    theme,
};

const SPINNER: [&str; 10] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

pub fn render(frame: &mut Frame<'_>, area: Rect, app: &AppState, layer: &str) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Min(5),
            Constraint::Length(3),
            Constraint::Length(4),
        ])
        .split(area);

    let block = Block::default()
        .title(format!("{layer} Progress"))
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::layer_color(layer)))
        .style(theme::panel());
    frame.render_widget(block, area);

    let items = if app.tweak_states.is_empty() {
        vec![ListItem::new(Line::from(Span::styled(
            "Waiting for backend...",
            theme::dim(),
        )))]
    } else {
        app.tweak_states
            .iter()
            .map(|tweak| {
                let (icon, style) = match tweak.status {
                    TweakStatus::Pending => ("●", theme::dim()),
                    TweakStatus::Done => ("✓", theme::success()),
                    TweakStatus::Failed => ("✗", theme::error()),
                    TweakStatus::Skipped => ("•", theme::warning()),
                    TweakStatus::InProgress => (
                        SPINNER[app.spinner_index % SPINNER.len()],
                        Style::default()
                            .fg(theme::ACCENT_CYAN)
                            .bg(theme::BG_PANEL)
                            .add_modifier(Modifier::BOLD),
                    ),
                };
                ListItem::new(Line::from(vec![
                    Span::styled(icon.to_string(), style),
                    Span::raw(" "),
                    Span::styled(tweak.name.clone(), style),
                ]))
            })
            .collect()
    };
    frame.render_widget(List::new(items).style(theme::panel()), chunks[0]);

    let percent = app.progress_percent();
    let gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded),
        )
        .gauge_style(
            Style::default()
                .fg(theme::layer_color(layer))
                .bg(theme::BG_SELECTED),
        )
        .percent(percent);
    frame.render_widget(gauge, chunks[1]);

    let logs = app
        .log_tail
        .iter()
        .rev()
        .take(3)
        .cloned()
        .collect::<Vec<_>>()
        .join("\n");
    frame.render_widget(
        Paragraph::new(logs).style(Style::default().fg(theme::FG_DIM).bg(theme::BG_PANEL)),
        chunks[2],
    );
}
