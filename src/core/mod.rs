//! Core domain types and logic

mod layer;
mod manifest;
mod module;
mod protected;
pub mod sysinfo;

pub use layer::{Layer, RiskLevel};
pub use manifest::Manifest;
pub use module::Module;
pub use protected::PROTECTED_SERVICES;
pub use sysinfo::{SystemInfo, CleanupEstimate};
