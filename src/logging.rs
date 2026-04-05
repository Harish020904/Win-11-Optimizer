//! Logging infrastructure

use anyhow::Result;
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

/// Initialize the logging system
pub fn init(verbose: bool) -> Result<()> {
    let filter = if verbose {
        EnvFilter::new("debug")
    } else {
        EnvFilter::new("info")
    };

    // Console logging with colors
    let console_layer = fmt::layer()
        .with_target(false)
        .with_level(true)
        .with_ansi(true);

    // File logging (JSON format)
    let log_dir = std::path::PathBuf::from(r"C:\ProgramData\WinOptimizer\logs");
    let _ = std::fs::create_dir_all(&log_dir);

    let log_file = log_dir.join(format!(
        "optimizer-{}.log",
        chrono::Local::now().format("%Y%m%d")
    ));

    let file_appender = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_file);

    if let Ok(file) = file_appender {
        let file_layer = fmt::layer()
            .with_target(true)
            .with_level(true)
            .with_ansi(false)
            .json()
            .with_writer(std::sync::Mutex::new(file));

        tracing_subscriber::registry()
            .with(filter)
            .with(console_layer)
            .with(file_layer)
            .init();
    } else {
        // Fall back to console-only logging
        tracing_subscriber::registry()
            .with(filter)
            .with(console_layer)
            .init();
    }

    Ok(())
}

/// Log an operation for audit purposes
pub fn log_operation(operation: &str, layer: Option<&str>, module: Option<&str>, success: bool) {
    if success {
        tracing::info!(
            operation = operation,
            layer = layer,
            module = module,
            "Operation completed successfully"
        );
    } else {
        tracing::error!(
            operation = operation,
            layer = layer,
            module = module,
            "Operation failed"
        );
    }
}

/// Log a security event
pub fn log_security_event(event: &str, details: &str) {
    tracing::warn!(
        event_type = "security",
        event = event,
        details = details,
        "Security event"
    );
}
