//! Module metadata parsing

use crate::core::RiskLevel;
use anyhow::Result;
use serde::Deserialize;
use std::path::Path;

/// Module metadata (from metadata.yaml files)
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Module {
    /// Module identifier
    pub id: String,

    /// Human-readable title
    pub title: String,

    /// Layer this module belongs to
    pub layer: String,

    /// Severity/importance
    #[serde(default)]
    pub severity: Option<String>,

    /// Whether changes are reversible
    #[serde(default = "default_reversible")]
    pub reversible: String,

    /// Summary of what this module does
    #[serde(default)]
    pub summary: String,

    /// Detailed description of changes
    #[serde(default, alias = "whatChanges")]
    pub what_changes: String,

    /// Risk level
    #[serde(default, alias = "riskLevel")]
    pub risk_level_str: Option<String>,

    /// Preview command to show current state
    #[serde(default, alias = "previewCommand")]
    pub preview_command: Option<String>,
}

fn default_reversible() -> String {
    "yes".to_string()
}

impl Module {
    /// Load module metadata from YAML file
    pub fn load(path: &Path) -> Result<Self> {
        let contents = std::fs::read_to_string(path)?;
        let module: Module = serde_yaml::from_str(&contents)?;
        Ok(module)
    }

    /// Get risk level enum
    pub fn risk_level(&self) -> RiskLevel {
        match self.risk_level_str.as_deref() {
            Some("low") => RiskLevel::Low,
            Some("medium") => RiskLevel::Medium,
            Some("high") => RiskLevel::High,
            _ => RiskLevel::Low,
        }
    }

    /// Check if module is reversible
    pub fn is_reversible(&self) -> bool {
        matches!(self.reversible.to_lowercase().as_str(), "yes" | "true" | "full")
    }

    /// Get short description (first sentence of summary)
    pub fn short_description(&self) -> &str {
        self.summary
            .split('.')
            .next()
            .unwrap_or(&self.summary)
            .trim()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_module() {
        let yaml = r#"
id: disable-telemetry
title: "Disable Diagnostic Telemetry"
layer: minimal
severity: low
reversible: yes
summary: "Disables Windows diagnostic telemetry services."
whatChanges: "Stops DiagTrack and dmwappushservice."
riskLevel: low
"#;
        let module: Module = serde_yaml::from_str(yaml).unwrap();
        assert_eq!(module.id, "disable-telemetry");
        assert!(module.is_reversible());
        assert_eq!(module.risk_level(), RiskLevel::Low);
    }
}
