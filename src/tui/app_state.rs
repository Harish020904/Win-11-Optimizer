//! TUI application state management

use crate::app::{AppContext, WizardSelections, WizardState};
use crate::core::Layer;

/// Full TUI application state
pub struct TuiState {
    /// Application context with modules and state
    pub ctx: AppContext,
    /// Current wizard screen
    pub screen: WizardState,
    /// User selections during wizard
    pub selections: WizardSelections,
    /// Menu/list selection index
    pub selected_index: usize,
    /// Should exit the application
    pub should_exit: bool,
    /// Status message to display
    pub status_message: Option<String>,
    /// Progress for apply/rollback operations
    pub progress: Option<Progress>,
    /// Log messages for current operation
    pub logs: Vec<LogEntry>,
}

/// Progress tracking for operations
#[derive(Debug, Clone)]
pub struct Progress {
    /// Current step
    pub current: usize,
    /// Total steps
    pub total: usize,
    /// Current step description
    pub description: String,
    /// Percentage complete
    pub percent: u8,
}

/// Log entry for display
#[derive(Debug, Clone)]
pub struct LogEntry {
    /// Timestamp
    pub time: String,
    /// Log level
    pub level: LogLevel,
    /// Message
    pub message: String,
}

/// Log level for display
#[derive(Debug, Clone, Copy)]
pub enum LogLevel {
    Info,
    Success,
    Warning,
    Error,
}

impl TuiState {
    /// Create new TUI state
    pub fn new(ctx: AppContext) -> Self {
        Self {
            ctx,
            screen: WizardState::Welcome,
            selections: WizardSelections::default(),
            selected_index: 0,
            should_exit: false,
            status_message: None,
            progress: None,
            logs: Vec::new(),
        }
    }

    /// Check if user can quit (not in middle of operation)
    pub fn can_quit(&self) -> bool {
        !matches!(
            self.screen,
            WizardState::Applying | WizardState::Verifying
        )
    }

    /// Navigate to next screen
    pub fn next_screen(&mut self) {
        self.screen = match &self.screen {
            WizardState::Welcome => WizardState::LayerSelect,
            WizardState::LayerSelect => WizardState::Preview,
            WizardState::Preview => WizardState::Consent,
            WizardState::Consent => WizardState::Applying,
            WizardState::Applying => WizardState::Verifying,
            WizardState::Verifying => WizardState::Complete,
            WizardState::Complete => WizardState::Welcome,
            WizardState::StatusDashboard => WizardState::StatusDashboard,
            WizardState::RollbackConfirm => WizardState::StatusDashboard,
            WizardState::ExitConfirm => WizardState::Welcome,
            WizardState::Error(_) => WizardState::Welcome,
        };
        self.selected_index = 0;
    }

    /// Navigate to previous screen
    pub fn prev_screen(&mut self) {
        self.screen = match &self.screen {
            WizardState::Welcome => WizardState::Welcome,
            WizardState::LayerSelect => WizardState::Welcome,
            WizardState::Preview => WizardState::LayerSelect,
            WizardState::Consent => WizardState::Preview,
            WizardState::Applying => WizardState::Consent, // Can't go back during apply
            WizardState::Verifying => WizardState::Applying,
            WizardState::Complete => WizardState::Welcome,
            WizardState::StatusDashboard => WizardState::Welcome,
            WizardState::RollbackConfirm => WizardState::StatusDashboard,
            WizardState::ExitConfirm => WizardState::Welcome,
            WizardState::Error(_) => WizardState::Welcome,
        };
        self.selected_index = 0;
    }

    /// Move selection up
    pub fn select_up(&mut self, max: usize) {
        if self.selected_index > 0 {
            self.selected_index -= 1;
        } else if max > 0 {
            self.selected_index = max - 1;
        }
    }

    /// Move selection down
    pub fn select_down(&mut self, max: usize) {
        if max > 0 && self.selected_index < max - 1 {
            self.selected_index += 1;
        } else {
            self.selected_index = 0;
        }
    }

    /// Get available layers for selection
    pub fn available_layers(&self) -> Vec<Layer> {
        Layer::all().to_vec()
    }

    /// Get selected layer
    pub fn selected_layer(&self) -> Option<Layer> {
        self.selections.selected_layer
    }

    /// Set selected layer
    pub fn set_selected_layer(&mut self, layer: Layer) {
        self.selections.selected_layer = Some(layer);
    }

    /// Add a log entry
    pub fn add_log(&mut self, level: LogLevel, message: &str) {
        let time = chrono::Local::now().format("%H:%M:%S").to_string();
        self.logs.push(LogEntry {
            time,
            level,
            message: message.to_string(),
        });
        // Keep only last 100 entries
        if self.logs.len() > 100 {
            self.logs.remove(0);
        }
    }

    /// Update progress
    pub fn set_progress(&mut self, current: usize, total: usize, description: &str) {
        let percent = if total > 0 {
            ((current as f32 / total as f32) * 100.0) as u8
        } else {
            0
        };

        self.progress = Some(Progress {
            current,
            total,
            description: description.to_string(),
            percent,
        });
    }

    /// Clear progress
    pub fn clear_progress(&mut self) {
        self.progress = None;
    }
}
