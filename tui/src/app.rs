use std::collections::VecDeque;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq)]
pub enum Screen {
    MainMenu,
    DisclaimerCard(DisclaimerData),
    LayerProgress(String),
    VerifyResults,
    RollbackConfirm(String),
    GodModeConfirmInput,
    StatusDetail,
    Error(String),
}

#[derive(Debug, Clone)]
pub struct AppState {
    pub screen: Screen,
    pub applied_layers: Vec<String>,
    pub system_metrics: SystemMetrics,
    pub menu_selected: usize,
    pub tweak_states: Vec<TweakState>,
    pub verify_results: Vec<VerifyResult>,
    pub global_run_all: bool,
    pub godmode_input_buf: String,
    pub log_tail: VecDeque<String>,
    pub dry_run: bool,
    pub should_quit: bool,
    pub current_layer: Option<String>,
    pub spinner_index: usize,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DisclaimerData {
    pub tweak_number: u32,
    pub layer: String,
    pub tweak_name: String,
    pub summary: String,
    pub what_changes: String,
    pub reversible: String,
    pub risk_level: String,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemMetrics {
    pub ram_used_gb: f64,
    pub ram_total_gb: f64,
    pub cpu_idle_percent: u8,
    pub process_count: u32,
    pub running_services: u32,
    pub defender_status: String,
    pub windows_update_status: String,
    pub applied_layers: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TweakState {
    pub id: u32,
    pub name: String,
    pub status: TweakStatus,
    pub message: String,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TweakStatus {
    Pending,
    InProgress,
    Done,
    Failed,
    Skipped,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VerifyResult {
    pub test: String,
    pub expected: String,
    pub actual: String,
    pub passed: bool,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            screen: Screen::MainMenu,
            applied_layers: Vec::new(),
            system_metrics: SystemMetrics {
                defender_status: "Unknown".to_string(),
                windows_update_status: "Unknown".to_string(),
                ..SystemMetrics::default()
            },
            menu_selected: 0,
            tweak_states: Vec::new(),
            verify_results: Vec::new(),
            global_run_all: false,
            godmode_input_buf: String::new(),
            log_tail: VecDeque::with_capacity(20),
            dry_run: false,
            should_quit: false,
            current_layer: None,
            spinner_index: 0,
            last_error: None,
        }
    }
}

impl AppState {
    pub const MENU_LEN: usize = 8;

    pub fn select_up(&mut self) {
        if self.menu_selected == 0 {
            self.menu_selected = Self::MENU_LEN - 1;
        } else {
            self.menu_selected -= 1;
        }
    }

    pub fn select_down(&mut self) {
        self.menu_selected = (self.menu_selected + 1) % Self::MENU_LEN;
    }

    pub fn push_log(&mut self, line: impl Into<String>) {
        if self.log_tail.len() == 20 {
            self.log_tail.pop_front();
        }
        self.log_tail.push_back(line.into());
    }

    pub fn set_metrics(&mut self, metrics: SystemMetrics) {
        self.applied_layers = metrics.applied_layers.clone();
        self.system_metrics = metrics;
    }

    pub fn begin_layer(&mut self, layer: impl Into<String>) {
        let layer = layer.into();
        self.current_layer = Some(layer.clone());
        self.screen = Screen::LayerProgress(layer);
        self.tweak_states.clear();
        self.verify_results.clear();
        self.last_error = None;
    }

    pub fn set_disclaimer(&mut self, data: DisclaimerData) {
        self.current_layer = Some(data.layer.clone());
        self.screen = Screen::DisclaimerCard(data);
    }

    pub fn update_tweak(&mut self, id: u32, name: String, status: TweakStatus, message: String) {
        if let Some(existing) = self.tweak_states.iter_mut().find(|t| t.id == id) {
            existing.name = name;
            existing.status = status;
            existing.message = message;
            return;
        }

        self.tweak_states.push(TweakState {
            id,
            name,
            status,
            message,
        });
    }

    pub fn progress_percent(&self) -> u16 {
        if self.tweak_states.is_empty() {
            return 0;
        }
        let completed = self
            .tweak_states
            .iter()
            .filter(|t| {
                matches!(
                    t.status,
                    TweakStatus::Done | TweakStatus::Failed | TweakStatus::Skipped
                )
            })
            .count();
        ((completed * 100) / self.tweak_states.len()) as u16
    }

    pub fn awaiting_consent(&self) -> bool {
        matches!(
            self.screen,
            Screen::DisclaimerCard(_) | Screen::GodModeConfirmInput
        )
    }

    pub fn layer_for_menu_index(index: usize) -> Option<&'static str> {
        match index {
            0 => Some("MINIMAL"),
            1 => Some("MODERATE"),
            2 => Some("ULTIMATE"),
            3 => Some("GODMODE"),
            _ => None,
        }
    }
}
