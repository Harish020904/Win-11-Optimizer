use ratatui::style::{Color, Modifier, Style};

pub const BG_PRIMARY: Color = Color::Rgb(0x2E, 0x34, 0x40);
pub const BG_PANEL: Color = Color::Rgb(0x3B, 0x42, 0x52);
pub const BG_SELECTED: Color = Color::Rgb(0x43, 0x4C, 0x5E);
pub const FG_PRIMARY: Color = Color::Rgb(0xEC, 0xEF, 0xF4);
pub const FG_DIM: Color = Color::Rgb(0x4C, 0x56, 0x6A);
pub const ACCENT_GREEN: Color = Color::Rgb(0xA3, 0xBE, 0x8C);
pub const ACCENT_YELLOW: Color = Color::Rgb(0xEB, 0xCB, 0x8B);
pub const ACCENT_ORANGE: Color = Color::Rgb(0xD0, 0x87, 0x70);
pub const ACCENT_RED: Color = Color::Rgb(0xBF, 0x61, 0x6A);
pub const ACCENT_CYAN: Color = Color::Rgb(0x88, 0xC0, 0xD0);
pub const ACCENT_BLUE: Color = Color::Rgb(0x5E, 0x81, 0xAC);

pub fn base() -> Style {
    Style::default().fg(FG_PRIMARY).bg(BG_PRIMARY)
}

pub fn panel() -> Style {
    Style::default().fg(FG_PRIMARY).bg(BG_PANEL)
}

pub fn selected() -> Style {
    Style::default()
        .fg(FG_PRIMARY)
        .bg(BG_SELECTED)
        .add_modifier(Modifier::BOLD)
}

pub fn dim() -> Style {
    Style::default().fg(FG_DIM).bg(BG_PANEL)
}

pub fn success() -> Style {
    Style::default().fg(ACCENT_GREEN).bg(BG_PANEL)
}

pub fn warning() -> Style {
    Style::default().fg(ACCENT_YELLOW).bg(BG_PANEL)
}

pub fn error() -> Style {
    Style::default().fg(ACCENT_RED).bg(BG_PANEL)
}

pub fn info() -> Style {
    Style::default().fg(ACCENT_CYAN).bg(BG_PANEL)
}

pub fn layer_color(layer: &str) -> Color {
    match layer.to_ascii_uppercase().as_str() {
        "MINIMAL" => ACCENT_GREEN,
        "MODERATE" | "MOD" => ACCENT_YELLOW,
        "ULTIMATE" => ACCENT_ORANGE,
        "GODMODE" | "GOD MODE" => ACCENT_RED,
        _ => ACCENT_CYAN,
    }
}

pub fn risk_color(risk: &str) -> Color {
    match risk.to_ascii_uppercase().as_str() {
        "ZERO" | "LOW" => ACCENT_GREEN,
        "MEDIUM" | "LOW-MEDIUM" => ACCENT_YELLOW,
        "HIGH" => ACCENT_RED,
        _ => ACCENT_ORANGE,
    }
}
