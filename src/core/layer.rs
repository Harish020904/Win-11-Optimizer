//! Layer definitions and progression logic

use serde::{Deserialize, Serialize};
use std::fmt;

/// Risk level for optimization operations
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RiskLevel {
    Low,
    Medium,
    High,
}

impl fmt::Display for RiskLevel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RiskLevel::Low => write!(f, "LOW"),
            RiskLevel::Medium => write!(f, "MEDIUM"),
            RiskLevel::High => write!(f, "HIGH"),
        }
    }
}

/// Optimization layers in progressive order
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Layer {
    Minimal,
    Moderate,
    Ultimate,
    GodMode,
}

impl Layer {
    /// Get all layers in order
    pub fn all() -> &'static [Layer] {
        &[
            Layer::Minimal,
            Layer::Moderate,
            Layer::Ultimate,
            Layer::GodMode,
        ]
    }

    /// Get layer from string name
    pub fn from_str(s: &str) -> anyhow::Result<Self> {
        match s.to_lowercase().as_str() {
            "minimal" => Ok(Layer::Minimal),
            "moderate" => Ok(Layer::Moderate),
            "ultimate" => Ok(Layer::Ultimate),
            "godmode" => Ok(Layer::GodMode),
            _ => anyhow::bail!("Unknown layer: {}. Valid: minimal, moderate, ultimate, godmode", s),
        }
    }

    /// Get layer name as string
    pub fn as_str(&self) -> &'static str {
        match self {
            Layer::Minimal => "minimal",
            Layer::Moderate => "moderate",
            Layer::Ultimate => "ultimate",
            Layer::GodMode => "godmode",
        }
    }

    /// Get human-readable display name
    pub fn display_name(&self) -> &'static str {
        match self {
            Layer::Minimal => "Minimal",
            Layer::Moderate => "Moderate",
            Layer::Ultimate => "Ultimate",
            Layer::GodMode => "GodMode",
        }
    }

    /// Get layer description
    pub fn description(&self) -> &'static str {
        match self {
            Layer::Minimal => "Reduce telemetry, disable widgets. Safe for all users.",
            Layer::Moderate => "Tune services, disable Xbox. Good for developers.",
            Layer::Ultimate => "Firewall hardening, policy tweaks. Enterprise level.",
            Layer::GodMode => "Maximum optimization. For advanced users only.",
        }
    }

    /// Get risk level for this layer
    pub fn risk_level(&self) -> RiskLevel {
        match self {
            Layer::Minimal => RiskLevel::Low,
            Layer::Moderate => RiskLevel::Low,
            Layer::Ultimate => RiskLevel::Medium,
            Layer::GodMode => RiskLevel::High,
        }
    }

    /// Get required prerequisite layer (if any)
    pub fn requires(&self) -> Option<Layer> {
        match self {
            Layer::Minimal => None,
            Layer::Moderate => Some(Layer::Minimal),
            Layer::Ultimate => Some(Layer::Moderate),
            Layer::GodMode => Some(Layer::Ultimate),
        }
    }

    /// Check if this layer can be applied given currently applied layers
    pub fn can_apply(&self, applied: &[Layer]) -> bool {
        match self.requires() {
            None => true,
            Some(required) => applied.contains(&required),
        }
    }

    /// Get the order index (0-3)
    pub fn order(&self) -> usize {
        match self {
            Layer::Minimal => 0,
            Layer::Moderate => 1,
            Layer::Ultimate => 2,
            Layer::GodMode => 3,
        }
    }

    /// Check if layer is fully reversible
    pub fn is_reversible(&self) -> bool {
        match self {
            Layer::Minimal => true,
            Layer::Moderate => true,
            Layer::Ultimate => true,
            Layer::GodMode => true, // All current modules are reversible
        }
    }
}

impl fmt::Display for Layer {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_layer_order() {
        assert_eq!(Layer::Minimal.order(), 0);
        assert_eq!(Layer::GodMode.order(), 3);
    }

    #[test]
    fn test_layer_dependencies() {
        assert!(Layer::Minimal.requires().is_none());
        assert_eq!(Layer::Moderate.requires(), Some(Layer::Minimal));
        assert_eq!(Layer::Ultimate.requires(), Some(Layer::Moderate));
        assert_eq!(Layer::GodMode.requires(), Some(Layer::Ultimate));
    }

    #[test]
    fn test_can_apply() {
        assert!(Layer::Minimal.can_apply(&[]));
        assert!(!Layer::Moderate.can_apply(&[]));
        assert!(Layer::Moderate.can_apply(&[Layer::Minimal]));
    }

    #[test]
    fn test_from_str() {
        assert_eq!(Layer::from_str("minimal").unwrap(), Layer::Minimal);
        assert_eq!(Layer::from_str("GODMODE").unwrap(), Layer::GodMode);
        assert!(Layer::from_str("invalid").is_err());
    }
}
