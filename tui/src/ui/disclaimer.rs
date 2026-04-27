use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Clear, Paragraph, Wrap},
    Frame,
};

use crate::{
    app::{AppState, DisclaimerData},
    theme,
};

pub fn render(frame: &mut Frame<'_>, area: Rect, data: &DisclaimerData) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Min(5),
            Constraint::Length(1),
            Constraint::Length(3),
            Constraint::Length(2),
        ])
        .split(area);

    let title = format!(
        "DISCLAIMER #{} [{}] - {}",
        data.tweak_number, data.layer, data.tweak_name
    );
    let block = Block::default()
        .title(title)
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::layer_color(&data.layer)))
        .style(theme::panel());
    frame.render_widget(block, area);

    let summary = Paragraph::new(data.summary.clone())
        .style(Style::default().fg(theme::FG_PRIMARY).bg(theme::BG_PANEL))
        .wrap(Wrap { trim: true });
    frame.render_widget(summary, chunks[0]);

    frame.render_widget(
        Paragraph::new("────────────────────────────────────────").style(theme::dim()),
        chunks[1],
    );

    let details = vec![
        Line::from(vec![
            Span::styled("AFFECTS: ", theme::info()),
            Span::styled(
                data.what_changes.clone(),
                Style::default().fg(theme::FG_PRIMARY),
            ),
        ]),
        Line::from(vec![
            Span::styled("REVERSIBLE: ", Style::default().fg(theme::ACCENT_BLUE)),
            Span::styled(
                data.reversible.clone(),
                Style::default().fg(if data.reversible.starts_with("YES") {
                    theme::ACCENT_GREEN
                } else {
                    theme::ACCENT_YELLOW
                }),
            ),
            Span::raw("  "),
            Span::styled("RISK: ", Style::default().fg(theme::ACCENT_BLUE)),
            Span::styled(
                data.risk_level.clone(),
                Style::default()
                    .fg(theme::risk_color(&data.risk_level))
                    .add_modifier(Modifier::BOLD),
            ),
        ]),
    ];
    frame.render_widget(Paragraph::new(details).wrap(Wrap { trim: true }), chunks[2]);

    frame.render_widget(
        Paragraph::new("[Y] Apply  [N] Skip  [A] Run All  [D] Dry-run  [Q] Quit")
            .style(Style::default().fg(theme::ACCENT_BLUE).bg(theme::BG_PANEL)),
        chunks[3],
    );
}

pub fn render_godmode_popup(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let width = area.width.min(52);
    let height = 7.min(area.height);
    let x = area.x + area.width.saturating_sub(width) / 2;
    let y = area.y + area.height.saturating_sub(height) / 2;
    let popup = Rect::new(x, y, width, height);

    frame.render_widget(Clear, popup);
    let block = Block::default()
        .title("GOD MODE confirmation")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_RED))
        .style(theme::panel());
    frame.render_widget(block, popup);

    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(2),
            Constraint::Length(1),
            Constraint::Length(1),
        ])
        .split(popup);
    frame.render_widget(
        Paragraph::new("Type GODMODE and press Enter to approve all God Mode tweaks.")
            .wrap(Wrap { trim: true })
            .style(Style::default().fg(theme::FG_PRIMARY).bg(theme::BG_PANEL)),
        inner[0],
    );
    frame.render_widget(
        Paragraph::new(app.godmode_input_buf.clone())
            .alignment(Alignment::Center)
            .style(
                Style::default()
                    .fg(theme::ACCENT_RED)
                    .bg(theme::BG_SELECTED)
                    .add_modifier(Modifier::BOLD),
            ),
        inner[1],
    );
    frame.render_widget(
        Paragraph::new("[Esc] Cancel")
            .alignment(Alignment::Center)
            .style(Style::default().fg(theme::ACCENT_BLUE).bg(theme::BG_PANEL)),
        inner[2],
    );
}
