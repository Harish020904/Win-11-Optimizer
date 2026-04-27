use ratatui::{
    layout::Rect,
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, List, ListItem, ListState},
    Frame,
};

use crate::{app::AppState, theme};

pub fn render(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let items = [
        menu_line("Apply MINIMAL", "MINIMAL", app),
        menu_line("Apply MODERATE", "MODERATE", app),
        menu_line("Apply ULTIMATE", "ULTIMATE", app),
        menu_line("Apply GOD MODE", "GODMODE", app),
        Line::from(Span::styled("──────────────────", theme::dim())),
        Line::from("    Rollback"),
        Line::from("    Verify System"),
        Line::from("    Snapshot Now"),
        Line::from("    Quit"),
    ];

    let list_items = items
        .into_iter()
        .map(|line| ListItem::new(line).style(theme::panel()))
        .collect::<Vec<_>>();

    let selected = match app.menu_selected {
        0..=3 => app.menu_selected,
        4 => 5,
        5 => 6,
        6 => 7,
        _ => 8,
    };

    let mut state = ListState::default();
    state.select(Some(selected));

    let block = Block::default()
        .title("Main Menu")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_CYAN))
        .style(theme::panel());

    let list = List::new(list_items)
        .block(block)
        .highlight_style(theme::selected())
        .highlight_symbol("▶ ");

    frame.render_stateful_widget(list, area, &mut state);
}

fn menu_line(label: &str, layer: &str, app: &AppState) -> Line<'static> {
    let applied = app
        .applied_layers
        .iter()
        .any(|applied| applied.eq_ignore_ascii_case(layer));
    let mark = if applied { "[✓]" } else { "[ ]" };
    let style = if applied {
        Style::default()
            .fg(theme::layer_color(layer))
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(theme::FG_PRIMARY)
    };

    Line::from(vec![
        Span::styled(mark.to_string(), style),
        Span::raw(" "),
        Span::styled(label.to_string(), style),
    ])
}
