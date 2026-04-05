//! State persistence for tracking applied layers

use crate::core::Layer;
use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

/// Information about an applied layer
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayerInfo {
    /// When the layer was applied
    pub applied_at: DateTime<Utc>,
    /// Modules that were applied
    pub modules: Vec<String>,
    /// Snapshot ID for rollback
    pub snapshot_id: Option<String>,
}

/// Persistent state for the optimizer
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct OptimizerState {
    /// Version of the state format
    pub version: u32,
    /// Applied layers with their info
    pub layers: HashMap<String, LayerInfo>,
    /// Last modification time
    pub last_modified: Option<DateTime<Utc>>,
}

/// Manager for reading/writing state
pub struct StateManager {
    state_path: PathBuf,
    state: OptimizerState,
}

impl StateManager {
    /// Create or load state manager
    pub fn new() -> Result<Self> {
        let state_dir = PathBuf::from(r"C:\ProgramData\WinOptimizer\state");
        std::fs::create_dir_all(&state_dir)?;

        let state_path = state_dir.join("state.json");
        let state = Self::load_state(&state_path)?;

        Ok(Self { state_path, state })
    }

    /// Load state from file
    fn load_state(path: &PathBuf) -> Result<OptimizerState> {
        if path.exists() {
            let contents = std::fs::read_to_string(path)?;
            let state: OptimizerState = serde_json::from_str(&contents)?;
            Ok(state)
        } else {
            Ok(OptimizerState {
                version: 1,
                ..Default::default()
            })
        }
    }

    /// Save state to file (atomic write)
    fn save_state(&self) -> Result<()> {
        let temp_path = self.state_path.with_extension("json.tmp");

        let mut state = self.state.clone();
        state.last_modified = Some(Utc::now());

        let contents = serde_json::to_string_pretty(&state)?;
        std::fs::write(&temp_path, contents)?;
        std::fs::rename(&temp_path, &self.state_path)?;

        Ok(())
    }

    /// Check if a layer is currently applied
    pub fn is_layer_applied(&self, layer: Layer) -> bool {
        self.state.layers.contains_key(layer.as_str())
    }

    /// Get list of applied layers in order
    pub fn applied_layers(&self) -> Vec<Layer> {
        Layer::all()
            .iter()
            .copied()
            .filter(|l| self.is_layer_applied(*l))
            .collect()
    }

    /// Get info about a specific layer
    pub fn get_layer_info(&self, layer: Layer) -> Option<LayerInfo> {
        self.state.layers.get(layer.as_str()).cloned()
    }

    /// Mark a layer as applied
    pub fn mark_layer_applied(&mut self, layer: Layer) -> Result<()> {
        self.mark_layer_applied_with_modules(layer, Vec::new(), None)
    }

    /// Mark a layer as applied with module details
    pub fn mark_layer_applied_with_modules(
        &mut self,
        layer: Layer,
        modules: Vec<String>,
        snapshot_id: Option<String>,
    ) -> Result<()> {
        let info = LayerInfo {
            applied_at: Utc::now(),
            modules,
            snapshot_id,
        };

        self.state.layers.insert(layer.as_str().to_string(), info);
        self.save_state()
    }

    /// Mark a layer as removed
    pub fn mark_layer_removed(&mut self, layer: Layer) -> Result<()> {
        self.state.layers.remove(layer.as_str());
        self.save_state()
    }

    /// Get the highest applied layer
    pub fn highest_applied_layer(&self) -> Option<Layer> {
        self.applied_layers().into_iter().max_by_key(|l| l.order())
    }

    /// Check if any layers are applied
    pub fn has_applied_layers(&self) -> bool {
        !self.state.layers.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn test_state_manager() -> (StateManager, TempDir) {
        let temp_dir = TempDir::new().unwrap();
        let state_path = temp_dir.path().join("state.json");

        let manager = StateManager {
            state_path,
            state: OptimizerState::default(),
        };

        (manager, temp_dir)
    }

    #[test]
    fn test_layer_tracking() {
        let (mut manager, _temp) = test_state_manager();

        assert!(!manager.is_layer_applied(Layer::Minimal));
        assert!(manager.applied_layers().is_empty());

        manager.mark_layer_applied(Layer::Minimal).unwrap();

        assert!(manager.is_layer_applied(Layer::Minimal));
        assert_eq!(manager.applied_layers(), vec![Layer::Minimal]);

        manager.mark_layer_removed(Layer::Minimal).unwrap();

        assert!(!manager.is_layer_applied(Layer::Minimal));
    }
}
