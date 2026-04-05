//! Win11 Optimizer - Production-Grade Windows 11 Optimization TUI
//!
//! A Rust-based terminal user interface for optimizing Windows 11 systems
//! through progressive optimization layers.

pub mod app;
pub mod core;
pub mod executor;
pub mod logging;
pub mod tui;

use anyhow::Result;
use clap::Parser;
use std::path::PathBuf;

/// Win11 Optimizer - Windows 11 Optimization TUI
#[derive(Parser, Debug)]
#[command(name = "win11-optimizer")]
#[command(author = "Win11 Optimizer Team")]
#[command(version = "2.0.0")]
#[command(about = "Production-grade Windows 11 optimization with TUI wizard")]
#[command(long_about = r#"
Win11 Optimizer provides a guided wizard interface for optimizing Windows 11 systems.

Optimization Layers (progressive):
  • Minimal   - Reduce telemetry, disable widgets (LOW RISK)
  • Moderate  - Tune services, disable Xbox (LOW-MEDIUM RISK)  
  • Ultimate  - Firewall hardening, policy tweaks (MEDIUM RISK)
  • GodMode   - Maximum optimization (HIGH RISK)

Each layer builds upon the previous and can be rolled back.
"#)]
struct Cli {
    /// Run in TUI wizard mode (default)
    #[arg(short, long, default_value_t = true)]
    tui: bool,

    /// Path to custom modules directory
    #[arg(short, long)]
    modules: Option<PathBuf>,

    /// Path to custom manifests directory  
    #[arg(short = 'M', long)]
    manifests: Option<PathBuf>,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,

    /// Skip admin privilege check (for testing only)
    #[arg(long, hide = true)]
    skip_admin_check: bool,

    /// Show current system status and exit
    #[arg(long)]
    status: bool,

    /// Apply a specific layer without TUI (for scripting)
    #[arg(long, value_name = "LAYER")]
    apply: Option<String>,

    /// Rollback a specific layer without TUI
    #[arg(long, value_name = "LAYER")]
    rollback: Option<String>,

    /// Preview changes for a layer without TUI
    #[arg(long, value_name = "LAYER")]
    preview: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    logging::init(cli.verbose)?;

    tracing::info!("Win11 Optimizer v{} starting", env!("CARGO_PKG_VERSION"));

    // Check for admin privileges on Windows
    #[cfg(windows)]
    if !cli.skip_admin_check && !executor::admin::is_elevated() {
        eprintln!("Error: Win11 Optimizer requires administrator privileges.");
        eprintln!("Please run from an elevated command prompt or PowerShell.");
        std::process::exit(1);
    }

    // Determine paths
    let base_path = std::env::current_exe()?
        .parent()
        .unwrap_or_else(|| std::path::Path::new("."))
        .to_path_buf();

    let modules_path = cli.modules.unwrap_or_else(|| base_path.join("modules"));
    let manifests_path = cli.manifests.unwrap_or_else(|| base_path.join("runtime").join("manifests"));

    // Create application context
    let mut ctx = app::AppContext::new(modules_path, manifests_path)?;

    // Handle CLI-only commands
    if cli.status {
        return app::commands::show_status(&ctx).await;
    }

    if let Some(layer) = cli.preview {
        return app::commands::preview_layer(&ctx, &layer).await;
    }

    if let Some(layer) = cli.apply {
        return app::commands::apply_layer(&mut ctx, &layer).await;
    }

    if let Some(layer) = cli.rollback {
        return app::commands::rollback_layer(&mut ctx, &layer).await;
    }

    // Run TUI wizard (default)
    tui::run(ctx).await
}
