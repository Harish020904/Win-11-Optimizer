use ratatui::{
    layout::Rect,
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph, Wrap},
    Frame,
};

use crate::{app::AppState, theme};

pub fn render(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let metrics = &app.system_metrics;
    let layer_badges = if metrics.applied_layers.is_empty() {
        "None".to_string()
    } else {
        metrics.applied_layers.join(", ")
    };

    let lines = vec![
        Line::from(vec![
            Span::styled("RAM: ", theme::info()),
            Span::raw(format!(
                "{:.1}/{:.1} GB",
                metrics.ram_used_gb, metrics.ram_total_gb
            )),
        ]),
        Line::from(vec![
            Span::styled("CPU idle: ", theme::info()),
            Span::raw(format!("{}%", metrics.cpu_idle_percent)),
        ]),
        Line::from(vec![
            Span::styled("Procs: ", theme::info()),
            Span::raw(metrics.process_count.to_string()),
        ]),
        Line::from(vec![
            Span::styled("Services: ", theme::info()),
            Span::raw(metrics.running_services.to_string()),
        ]),
        Line::from(vec![
            Span::styled("Defender: ", theme::info()),
            Span::styled(
                status_mark(&metrics.defender_status),
                service_style(&metrics.defender_status),
            ),
        ]),
        Line::from(vec![
            Span::styled("WU: ", theme::info()),
            Span::styled(
                metrics.windows_update_status.clone(),
                service_style(&metrics.windows_update_status),
            ),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("Layers: ", theme::info()),
            Span::raw(layer_badges),
        ]),
    ];

    let block = Block::default()
        .title("Live Status")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_BLUE))
        .style(theme::panel());
    frame.render_widget(
        Paragraph::new(lines).block(block).wrap(Wrap { trim: true }),
        area,
    );
}

pub fn render_detail(frame: &mut Frame<'_>, area: Rect, app: &AppState) {
    let lines = vec![
        Line::from(Span::styled(
            "System Metrics",
            Style::default()
                .fg(theme::ACCENT_CYAN)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(format!(
            "RAM used: {:.1} GB",
            app.system_metrics.ram_used_gb
        )),
        Line::from(format!(
            "RAM total: {:.1} GB",
            app.system_metrics.ram_total_gb
        )),
        Line::from(format!(
            "CPU idle: {}%",
            app.system_metrics.cpu_idle_percent
        )),
        Line::from(format!("Processes: {}", app.system_metrics.process_count)),
        Line::from(format!(
            "Running services: {}",
            app.system_metrics.running_services
        )),
        Line::from(format!("Defender: {}", app.system_metrics.defender_status)),
        Line::from(format!(
            "Windows Update: {}",
            app.system_metrics.windows_update_status
        )),
    ];
    let block = Block::default()
        .title("Status Detail")
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_CYAN))
        .style(theme::panel());
    frame.render_widget(Paragraph::new(lines).block(block), area);
}

fn status_mark(status: &str) -> String {
    if status.eq_ignore_ascii_case("enabled") || status.eq_ignore_ascii_case("running") {
        "✓".to_string()
    } else {
        status.to_string()
    }
}

fn service_style(status: &str) -> Style {
    if status.eq_ignore_ascii_case("enabled") || status.eq_ignore_ascii_case("running") {
        theme::success()
    } else {
        theme::warning()
    }
}
