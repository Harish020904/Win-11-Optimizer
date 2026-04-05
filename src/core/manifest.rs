//! Layer manifest parsing

use crate::core::{Layer, RiskLevel};
use anyhow::Result;
use serde::Deserialize;
use std::path::Path;

/// Layer manifest definition (from YAML files)
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Manifest {
    /// Manifest name
    pub name: String,

    /// Layer description
    pub description: String,

    /// Layer identifier
    pub layer: String,

    /// Risk level
    #[serde(default)]
    pub risk_level: Option<String>,

    /// List of module IDs to include
    pub modules: Vec<String>,
}

impl Manifest {
    /// Load manifest from YAML file
    pub fn load(path: &Path) -> Result<Self> {
        let contents = std::fs::read_to_string(path)?;
        let manifest: Manifest = serde_yaml::from_str(&contents)?;
        Ok(manifest)
    }

    /// Get the layer enum value
    pub fn get_layer(&self) -> Result<Layer> {
        Layer::from_str(&self.layer)
    }

    /// Get risk level
    pub fn get_risk_level(&self) -> RiskLevel {
        match self.risk_level.as_deref() {
            Some("low") => RiskLevel::Low,
            Some("medium") => RiskLevel::Medium,
            Some("high") => RiskLevel::High,
            _ => RiskLevel::Low,
        }
    }

    /// Get module count
    pub fn module_count(&self) -> usize {
        self.modules.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_manifest() {
        let yaml = r#"
name: "Minimal"
description: "Reduce telemetry and UI noise"
layer: minimal
riskLevel: low
modules:
  - disable-telemetry
  - disable-widgets
"#;
        let manifest: Manifest = serde_yaml::from_str(yaml).unwrap();
        assert_eq!(manifest.name, "Minimal");
        assert_eq!(manifest.modules.len(), 2);
        assert_eq!(manifest.get_layer().unwrap(), Layer::Minimal);
    }
}
