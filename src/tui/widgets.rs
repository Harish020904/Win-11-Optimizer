//! Reusable TUI widgets

use crate::tui::theme::Theme;
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph},
    Frame,
};

/// Draw a centered title block
pub fn draw_title(frame: &mut Frame, area: Rect, title: &str, subtitle: Option<&str>) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border_focus())
        .title(Span::styled(
            format!(" {} ", title),
            Theme::title(),
        ))
        .title_alignment(Alignment::Center);

    if let Some(sub) = subtitle {
        let inner = block.inner(area);
        frame.render_widget(block, area);

        let text = Paragraph::new(sub)
            .style(Theme::subtitle())
            .alignment(Alignment::Center);
        frame.render_widget(text, inner);
    } else {
        frame.render_widget(block, area);
    }
}

/// Draw a button-like element
pub fn draw_button(frame: &mut Frame, area: Rect, label: &str, selected: bool) {
    let style = if selected {
        Theme::selected()
    } else {
        Theme::normal()
    };

    let button = Paragraph::new(format!(" {} ", label))
        .style(style)
        .alignment(Alignment::Center);

    frame.render_widget(button, area);
}

/// Draw a selection list
pub fn draw_selection_list(
    frame: &mut Frame,
    area: Rect,
    title: &str,
    items: &[(&str, &str)], // (label, description)
    selected: usize,
) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border())
        .title(Span::styled(format!(" {} ", title), Theme::title()));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let list_items: Vec<ListItem> = items
        .iter()
        .enumerate()
        .map(|(i, (label, desc))| {
            let style = if i == selected {
                Theme::selected()
            } else {
                Theme::normal()
            };

            let prefix = if i == selected { "▶ " } else { "  " };
            let content = Line::from(vec![
                Span::styled(prefix, style),
                Span::styled(*label, style.add_modifier(Modifier::BOLD)),
                Span::styled(format!(" - {}", desc), Theme::dim()),
            ]);

            ListItem::new(content)
        })
        .collect();

    let list = List::new(list_items);
    frame.render_widget(list, inner);
}

/// Draw a progress bar
pub fn draw_progress(
    frame: &mut Frame,
    area: Rect,
    label: &str,
    percent: u8,
) {
    let gauge = Gauge::default()
        .block(Block::default().borders(Borders::ALL).title(label))
        .gauge_style(
            Style::default()
                .fg(Theme::PRIMARY)
                .bg(Theme::BACKGROUND),
        )
        .percent(percent as u16)
        .label(format!("{}%", percent));

    frame.render_widget(gauge, area);
}

/// Draw a log panel
pub fn draw_log_panel(
    frame: &mut Frame,
    area: Rect,
    title: &str,
    logs: &[super::app_state::LogEntry],
) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border())
        .title(Span::styled(format!(" {} ", title), Theme::title()));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let log_items: Vec<ListItem> = logs
        .iter()
        .rev()
        .take(inner.height as usize)
        .map(|entry| {
            let style = match entry.level {
                super::app_state::LogLevel::Info => Theme::normal(),
                super::app_state::LogLevel::Success => Theme::success(),
                super::app_state::LogLevel::Warning => Theme::warning(),
                super::app_state::LogLevel::Error => Theme::error(),
            };

            let content = Line::from(vec![
                Span::styled(format!("[{}] ", entry.time), Theme::dim()),
                Span::styled(&entry.message, style),
            ]);

            ListItem::new(content)
        })
        .collect();

    let list = List::new(log_items);
    frame.render_widget(list, inner);
}

/// Draw help text at bottom
pub fn draw_help(frame: &mut Frame, area: Rect, keys: &[(&str, &str)]) {
    let help_text: Vec<Span> = keys
        .iter()
        .flat_map(|(key, desc)| {
            vec![
                Span::styled(format!(" {} ", key), Theme::highlight()),
                Span::styled(format!("{} ", desc), Theme::dim()),
            ]
        })
        .collect();

    let help = Paragraph::new(Line::from(help_text)).alignment(Alignment::Center);
    frame.render_widget(help, area);
}

/// Create a centered layout
pub fn centered_rect(percent_x: u16, percent_y: u16, area: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(area);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}
