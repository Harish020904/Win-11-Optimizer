//! Color theme and styling for TUI

use ratatui::style::{Color, Modifier, Style};

/// Theme colors
pub struct Theme;

impl Theme {
    // Primary colors
    pub const PRIMARY: Color = Color::Cyan;
    pub const SECONDARY: Color = Color::Blue;
    pub const ACCENT: Color = Color::Magenta;

    // Status colors
    pub const SUCCESS: Color = Color::Green;
    pub const WARNING: Color = Color::Yellow;
    pub const ERROR: Color = Color::Red;
    pub const INFO: Color = Color::Cyan;

    // Risk level colors
    pub const RISK_LOW: Color = Color::Green;
    pub const RISK_MEDIUM: Color = Color::Yellow;
    pub const RISK_HIGH: Color = Color::Red;

    // UI colors
    pub const BORDER: Color = Color::Gray;
    pub const BORDER_FOCUS: Color = Color::Cyan;
    pub const TEXT: Color = Color::White;
    pub const TEXT_DIM: Color = Color::DarkGray;
    pub const BACKGROUND: Color = Color::Reset;
    pub const SELECTION: Color = Color::Cyan;

    // Styles
    pub fn title() -> Style {
        Style::default()
            .fg(Self::PRIMARY)
            .add_modifier(Modifier::BOLD)
    }

    pub fn subtitle() -> Style {
        Style::default().fg(Self::TEXT_DIM)
    }

    pub fn normal() -> Style {
        Style::default().fg(Self::TEXT)
    }

    pub fn dim() -> Style {
        Style::default().fg(Self::TEXT_DIM)
    }

    pub fn selected() -> Style {
        Style::default()
            .fg(Self::BACKGROUND)
            .bg(Self::SELECTION)
            .add_modifier(Modifier::BOLD)
    }

    pub fn highlight() -> Style {
        Style::default()
            .fg(Self::PRIMARY)
            .add_modifier(Modifier::BOLD)
    }

    pub fn success() -> Style {
        Style::default().fg(Self::SUCCESS)
    }

    pub fn warning() -> Style {
        Style::default().fg(Self::WARNING)
    }

    pub fn error() -> Style {
        Style::default().fg(Self::ERROR)
    }

    pub fn border() -> Style {
        Style::default().fg(Self::BORDER)
    }

    pub fn border_focus() -> Style {
        Style::default().fg(Self::BORDER_FOCUS)
    }

    pub fn risk_color(level: &crate::core::RiskLevel) -> Color {
        match level {
            crate::core::RiskLevel::Low => Self::RISK_LOW,
            crate::core::RiskLevel::Medium => Self::RISK_MEDIUM,
            crate::core::RiskLevel::High => Self::RISK_HIGH,
        }
    }

    pub fn risk_style(level: &crate::core::RiskLevel) -> Style {
        Style::default().fg(Self::risk_color(level))
    }
}

/// Box drawing characters
pub struct BoxChars;

impl BoxChars {
    pub const HORIZONTAL: &'static str = "─";
    pub const VERTICAL: &'static str = "│";
    pub const TOP_LEFT: &'static str = "╭";
    pub const TOP_RIGHT: &'static str = "╮";
    pub const BOTTOM_LEFT: &'static str = "╰";
    pub const BOTTOM_RIGHT: &'static str = "╯";
    pub const BULLET: &'static str = "•";
    pub const ARROW_RIGHT: &'static str = "→";
    pub const CHECK: &'static str = "✓";
    pub const CROSS: &'static str = "✗";
    pub const WARNING: &'static str = "⚠";
    pub const INFO: &'static str = "ℹ";
}
