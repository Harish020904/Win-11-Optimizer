pub mod disclaimer;
pub mod layout;
pub mod menu;
pub mod progress;
pub mod rollback;
pub mod status;
pub mod verify;

use ratatui::{
    style::Style,
    widgets::{Block, Borders, Clear, Paragraph},
    Frame,
};

use crate::{
    app::{AppState, Screen},
    theme,
};

pub fn render(frame: &mut Frame<'_>, app: &AppState) {
    let area = frame.size();
    frame.render_widget(Block::default().style(theme::base()), area);

    let chunks = layout::root_chunks(area);
    layout::render_header(frame, chunks.header, app);
    layout::render_status_bar(frame, chunks.status_bar, app);

    let body = layout::body_chunks(chunks.body);
    status::render(frame, body.status, app);

    match &app.screen {
        Screen::MainMenu => menu::render(frame, body.main, app),
        Screen::DisclaimerCard(data) => disclaimer::render(frame, body.main, data),
        Screen::LayerProgress(layer) => progress::render(frame, body.main, app, layer),
        Screen::VerifyResults => verify::render(frame, body.main, app),
        Screen::RollbackConfirm(layer) => rollback::render(frame, body.main, app, layer),
        Screen::GodModeConfirmInput => disclaimer::render_godmode_popup(frame, area, app),
        Screen::StatusDetail => status::render_detail(frame, body.main, app),
        Screen::Error(message) => render_error(frame, body.main, message),
    }

    if matches!(app.screen, Screen::GodModeConfirmInput) {
        disclaimer::render_godmode_popup(frame, area, app);
    }
}

fn render_error(frame: &mut Frame<'_>, area: ratatui::layout::Rect, message: &str) {
    let block = Block::default()
        .title("Backend Error")
        .borders(Borders::ALL)
        .border_type(ratatui::widgets::BorderType::Rounded)
        .border_style(Style::default().fg(theme::ACCENT_RED))
        .style(theme::panel());
    let paragraph = Paragraph::new(message.to_string())
        .block(block)
        .wrap(ratatui::widgets::Wrap { trim: true });
    frame.render_widget(Clear, area);
    frame.render_widget(paragraph, area);
}
