//! Reusable TUI widgets

use crate::tui::theme::Theme;
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph},
    Frame,
};

/// ASCII art logo for Win11-Optimizer (3D style)
pub fn ascii_logo() -> Vec<Line<'static>> {
    vec![
        Line::from(vec![
            Span::styled("██╗    ██╗██╗███╗   ██╗", Theme::title()),
            Span::styled(" ╗╗  ", Theme::dim()),
            Span::styled("   ██████╗ ██████╗ ████████╗██╗███╗   ███╗██╗███████╗███████╗██████╗ ", Theme::highlight()),
        ]),
        Line::from(vec![
            Span::styled("██║    ██║██║████╗  ██║", Theme::title()),
            Span::styled("███║  ", Theme::dim()),
            Span::styled("  ██╔═══██╗██╔══██╗╚══██╔══╝██║████╗ ████║██║╚══███╔╝██╔════╝██╔══██╗", Theme::highlight()),
        ]),
        Line::from(vec![
            Span::styled("██║ █╗ ██║██║██╔██╗ ██║", Theme::title()),
            Span::styled("╚██║  ", Theme::dim()),
            Span::styled("  ██║   ██║██████╔╝   ██║   ██║██╔████╔██║██║  ███╔╝ █████╗  ██████╔╝", Theme::highlight()),
        ]),
        Line::from(vec![
            Span::styled("██║███╗██║██║██║╚██╗██║", Theme::dim()),
            Span::styled(" ██║  ", Theme::dim()),
            Span::styled("  ██║   ██║██╔═══╝    ██║   ██║██║╚██╔╝██║██║ ███╔╝  ██╔══╝  ██╔══██╗", Theme::dim()),
        ]),
        Line::from(vec![
            Span::styled("╚███╔███╔╝██║██║ ╚████║", Theme::dim()),
            Span::styled("███║  ", Theme::dim()),
            Span::styled("  ╚██████╔╝██║        ██║   ██║██║ ╚═╝ ██║██║███████╗███████╗██║  ██║", Theme::dim()),
        ]),
        Line::from(vec![
            Span::styled(" ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝", Theme::dim()),
            Span::styled("╚══╝  ", Theme::dim()),
            Span::styled("   ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝", Theme::dim()),
        ]),
    ]
}

/// Draw a left sidebar menu
pub fn draw_sidebar(
    frame: &mut Frame,
    area: Rect,
    title: &str,
    items: &[(&str, &str, bool)], // (label, icon, is_selected)
    focused: bool,
) {
    let border_style = if focused {
        Theme::border_focus()
    } else {
        Theme::border()
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(border_style)
        .title(Span::styled(format!(" {} ", title), Theme::title()));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let list_items: Vec<ListItem> = items
        .iter()
        .map(|(label, icon, selected)| {
            let style = if *selected {
                Theme::selected()
            } else {
                Theme::normal()
            };

            let prefix = if *selected { "▶ " } else { "  " };
            let content = Line::from(vec![
                Span::styled(prefix, style),
                Span::styled(format!("{} ", icon), Theme::highlight()),
                Span::styled(*label, style),
            ]);

            ListItem::new(content)
        })
        .collect();

    let list = List::new(list_items);
    frame.render_widget(list, inner);
}

/// Draw a system info panel (enhanced with Windows insights)
pub fn draw_system_info(frame: &mut Frame, area: Rect, sysinfo: &Option<crate::core::SystemInfo>) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border())
        .title(Span::styled(" SYSTEM INFO ", Theme::title()));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let info_lines = if let Some(info) = sysinfo {
        vec![
            Line::from(vec![
                Span::styled("OS:      ", Theme::dim()),
                Span::styled(
                    format!("{} ({})", info.os_version.chars().take(20).collect::<String>(), info.build_number),
                    Theme::normal()
                ),
            ]),
            Line::from(vec![
                Span::styled("CPU:     ", Theme::dim()),
                Span::styled(
                    format!("{} ({} cores)", 
                        info.cpu_model.chars().take(25).collect::<String>(),
                        info.cpu_cores
                    ),
                    Theme::normal()
                ),
            ]),
            Line::from(vec![
                Span::styled("RAM:     ", Theme::dim()),
                Span::styled(
                    format!("{:.1} GB / {:.1} GB", info.available_ram_gb, info.total_ram_gb),
                    Theme::normal()
                ),
                Span::styled(
                    format!(" ({:.0}% free)", (info.available_ram_gb / info.total_ram_gb) * 100.0),
                    Theme::dim()
                ),
            ]),
            Line::from(vec![
                Span::styled("GPU:     ", Theme::dim()),
                Span::styled(
                    info.gpu.chars().take(30).collect::<String>(),
                    Theme::normal()
                ),
            ]),
            Line::from(vec![
                Span::styled("Disk:    ", Theme::dim()),
                Span::styled(
                    format!("{:.1} GB / {:.1} GB", info.disk_used_gb, info.disk_total_gb),
                    Theme::normal()
                ),
                Span::styled(
                    format!(" ({:.0}% used)", (info.disk_used_gb / info.disk_total_gb) * 100.0),
                    Theme::dim()
                ),
            ]),
            Line::from(vec![
                Span::styled("Host:    ", Theme::dim()),
                Span::styled(format!("{}@{}", info.username, info.hostname), Theme::normal()),
            ]),
            Line::from(vec![
                Span::styled("Uptime:  ", Theme::dim()),
                Span::styled(&info.uptime, Theme::normal()),
            ]),
        ]
    } else {
        vec![
            Line::from(Span::styled("Loading system info...", Theme::dim())),
        ]
    };

    let info = Paragraph::new(info_lines);
    frame.render_widget(info, inner);
}

/// Draw cleanup estimation panel
pub fn draw_cleanup_estimate(frame: &mut Frame, area: Rect, cleanup: &Option<crate::core::CleanupEstimate>) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Theme::border())
        .title(Span::styled(" CLEANUP POTENTIAL ", Theme::warning()));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    let cleanup_lines = if let Some(est) = cleanup {
        vec![
            Line::from(""),
            Line::from(vec![
                Span::styled("  Total Reclaimable:  ", Theme::dim()),
                Span::styled(
                    format!("{:.2} GB", est.total_cleanup_gb),
                    Theme::success().add_modifier(Modifier::BOLD)
                ),
            ]),
            Line::from(""),
            Line::from(vec![
                Span::styled("  • Temp Files:       ", Theme::dim()),
                Span::styled(format!("{:.2} GB", est.temp_files_gb), Theme::normal()),
            ]),
            Line::from(vec![
                Span::styled("  • Update Cache:     ", Theme::dim()),
                Span::styled(format!("{:.2} GB", est.update_cache_gb), Theme::normal()),
            ]),
            Line::from(vec![
                Span::styled("  • Recycle Bin:      ", Theme::dim()),
                Span::styled(format!("{:.2} GB", est.recycle_bin_gb), Theme::normal()),
            ]),
            if est.windows_old_gb > 0.0 {
                Line::from(vec![
                    Span::styled("  • Windows.old:      ", Theme::dim()),
                    Span::styled(format!("{:.2} GB", est.windows_old_gb), Theme::warning()),
                ])
            } else {
                Line::from("")
            },
        ]
    } else {
        vec![
            Line::from(""),
            Line::from(Span::styled("  Calculating...", Theme::dim())),
        ]
    };

    let cleanup = Paragraph::new(cleanup_lines);
    frame.render_widget(cleanup, inner);
}

/// Draw a tech-style header
pub fn draw_tech_header(frame: &mut Frame, area: Rect, version: &str) {
    let layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(6),  // Logo (6 lines for 3D ASCII)
            Constraint::Length(1),  // Version
        ])
        .split(area);

    // Logo
    let logo = Paragraph::new(ascii_logo())
        .alignment(Alignment::Center);
    frame.render_widget(logo, layout[0]);

    // Version and divider
    let version_line = Line::from(vec![
        Span::styled("═".repeat(layout[1].width as usize / 3), Theme::border()),
        Span::styled(format!(" v{} ", version), Theme::highlight().add_modifier(Modifier::BOLD)),
        Span::styled("Windows 11 System Optimizer ", Theme::dim()),
        Span::styled("═".repeat(layout[1].width as usize / 3), Theme::border()),
    ]);
    let version_text = Paragraph::new(version_line).alignment(Alignment::Center);
    frame.render_widget(version_text, layout[1]);
}

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
