//! Application state and context management

use crate::core::{Layer, Manifest, Module};
use crate::executor::state::StateManager;
use anyhow::Result;
use std::path::PathBuf;

/// Application context holding paths and shared state
pub struct AppContext {
    /// Path to modules directory
    pub modules_path: PathBuf,
    /// Path to manifests directory
    pub manifests_path: PathBuf,
    /// State manager for tracking applied layers
    pub state: StateManager,
    /// Loaded manifests by layer
    pub manifests: std::collections::HashMap<Layer, Manifest>,
}

impl AppContext {
    /// Create a new application context
    pub fn new(modules_path: PathBuf, manifests_path: PathBuf) -> Result<Self> {
        let state = StateManager::new()?;
        let manifests = Self::load_manifests(&manifests_path)?;

        Ok(Self {
            modules_path,
            manifests_path,
            state,
            manifests,
        })
    }

    /// Load all layer manifests
    fn load_manifests(
        manifests_path: &PathBuf,
    ) -> Result<std::collections::HashMap<Layer, Manifest>> {
        let mut manifests = std::collections::HashMap::new();

        for layer in Layer::all() {
            let manifest_file = manifests_path.join(format!("{}.yaml", layer.as_str()));
            if manifest_file.exists() {
                match Manifest::load(&manifest_file) {
                    Ok(manifest) => {
                        manifests.insert(*layer, manifest);
                    }
                    Err(e) => {
                        tracing::warn!("Failed to load manifest for {:?}: {}", layer, e);
                    }
                }
            }
        }

        Ok(manifests)
    }

    /// Get all modules for a layer
    pub fn get_modules(&self, layer: Layer) -> Result<Vec<Module>> {
        let manifest = self
            .manifests
            .get(&layer)
            .ok_or_else(|| anyhow::anyhow!("No manifest found for layer {:?}", layer))?;

        let mut modules = Vec::new();
        for module_id in &manifest.modules {
            let module_path = self
                .modules_path
                .join(layer.as_str())
                .join(module_id)
                .join("metadata.yaml");

            if module_path.exists() {
                match Module::load(&module_path) {
                    Ok(module) => modules.push(module),
                    Err(e) => {
                        tracing::warn!("Failed to load module {}: {}", module_id, e);
                    }
                }
            }
        }

        Ok(modules)
    }

    /// Check if a layer is currently applied
    pub fn is_layer_applied(&self, layer: Layer) -> bool {
        self.state.is_layer_applied(layer)
    }

    /// Get list of applied layers
    pub fn applied_layers(&self) -> Vec<Layer> {
        self.state.applied_layers()
    }
}

/// Application state for TUI wizard
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WizardState {
    /// Welcome screen
    Welcome,
    /// Layer selection
    LayerSelect,
    /// Preview changes
    Preview,
    /// Module consent
    Consent,
    /// Applying changes
    Applying,
    /// Verifying changes
    Verifying,
    /// Completion screen
    Complete,
    /// Error state
    Error(String),
    /// Status dashboard
    StatusDashboard,
    /// Rollback confirmation
    RollbackConfirm,
    /// Exit confirmation
    ExitConfirm,
}

impl Default for WizardState {
    fn default() -> Self {
        Self::Welcome
    }
}

/// User selections during wizard flow
#[derive(Debug, Clone, Default)]
pub struct WizardSelections {
    /// Selected layer to apply
    pub selected_layer: Option<Layer>,
    /// Modules approved for application
    pub approved_modules: Vec<String>,
    /// Modules to skip
    pub skipped_modules: Vec<String>,
}
