use ratatui::{
    layout::{Constraint, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Cell, Paragraph, Row, Table},
    Frame,
};

use crate::{app::AppState, theme};

pub fn render(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let block = Block::default()
        .title("Verification")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_CYAN))
        .style(theme::panel());
    let inner = block.inner(area);
    frame.render_widget(block, area);

    if app.verify_results.is_empty() {
        frame.render_widget(
            Paragraph::new("Waiting for verification results...")
                .style(Style::default().fg(theme::FG_DIM).bg(theme::BG_PANEL)),
            inner,
        );
        return;
    }

    let footer_height = 2;
    let table_area = Rect {
        height: inner.height.saturating_sub(footer_height),
        ..inner
    };
    let footer_area = Rect {
        y: inner.y + inner.height.saturating_sub(footer_height),
        height: footer_height,
        ..inner
    };

    let rows = app.verify_results.iter().map(|result| {
        let style = if result.passed {
            theme::success()
        } else {
            theme::error().add_modifier(Modifier::BOLD)
        };
        Row::new(vec![
            Cell::from(result.test.clone()),
            Cell::from(result.expected.clone()),
            Cell::from(result.actual.clone()),
            Cell::from(if result.passed { "PASS" } else { "FAIL" }),
        ])
        .style(style)
    });

    let table = Table::new(
        rows,
        [
            Constraint::Percentage(30),
            Constraint::Percentage(30),
            Constraint::Percentage(25),
            Constraint::Percentage(15),
        ],
    )
    .header(
        Row::new(["TEST", "EXPECTED", "ACTUAL", "STATUS"]).style(
            Style::default()
                .fg(theme::ACCENT_BLUE)
                .add_modifier(Modifier::BOLD),
        ),
    );
    frame.render_widget(table, table_area);

    let failures = app
        .verify_results
        .iter()
        .filter(|result| !result.passed)
        .count();
    let footer = if failures == 0 {
        Line::from(Span::styled(
            "ALL CHECKS PASSED",
            Style::default()
                .fg(theme::ACCENT_GREEN)
                .add_modifier(Modifier::BOLD),
        ))
    } else {
        Line::from(Span::styled(
            format!("{failures} FAILURES - DO NOT PROCEED"),
            Style::default()
                .fg(theme::ACCENT_RED)
                .add_modifier(Modifier::BOLD),
        ))
    };
    frame.render_widget(Paragraph::new(footer).style(theme::panel()), footer_area);
}
