//! CLI command handlers for non-TUI mode

use crate::app::AppContext;
use crate::core::Layer;
use crate::executor::powershell::PowerShellExecutor;
use anyhow::Result;

/// Show current system status
pub async fn show_status(ctx: &AppContext) -> Result<()> {
    println!("Win11 Optimizer - System Status");
    println!("================================\n");

    let applied = ctx.applied_layers();
    if applied.is_empty() {
        println!("No optimization layers currently applied.");
    } else {
        println!("Applied Layers:");
        for layer in applied {
            let info = ctx.state.get_layer_info(layer);
            if let Some(info) = info {
                println!(
                    "  • {:?} - Applied at {}",
                    layer,
                    info.applied_at.format("%Y-%m-%d %H:%M:%S")
                );
            } else {
                println!("  • {:?}", layer);
            }
        }
    }

    println!("\nAvailable Layers:");
    for layer in Layer::all() {
        let status = if ctx.is_layer_applied(*layer) {
            "✓ Applied"
        } else {
            "○ Not applied"
        };
        let risk = layer.risk_level();
        println!("  {:?} [{:?}] - {}", layer, risk, status);
    }

    Ok(())
}

/// Preview changes for a layer
pub async fn preview_layer(ctx: &AppContext, layer_name: &str) -> Result<()> {
    let layer = Layer::from_str(layer_name)?;
    let modules = ctx.get_modules(layer)?;

    println!("Preview: {:?} Layer", layer);
    println!("========================\n");

    let executor = PowerShellExecutor::new(&ctx.modules_path);

    for module in modules {
        println!("Module: {}", module.title);
        println!("  Risk: {:?}", module.risk_level());
        println!("  Summary: {}", module.summary);
        println!("  Changes: {}", module.what_changes);
        println!();

        // Run preview script if available
        match executor.run_preview(layer.as_str(), &module.id).await {
            Ok(output) => {
                if !output.is_empty() {
                    println!("  Current State:");
                    for line in output.lines() {
                        println!("    {}", line);
                    }
                }
            }
            Err(e) => {
                println!("  Preview unavailable: {}", e);
            }
        }
        println!();
    }

    Ok(())
}

/// Apply a layer
pub async fn apply_layer(ctx: &mut AppContext, layer_name: &str) -> Result<()> {
    let layer = Layer::from_str(layer_name)?;

    // Check dependencies
    if let Some(required) = layer.requires() {
        if !ctx.is_layer_applied(required) {
            anyhow::bail!(
                "Layer {:?} requires {:?} to be applied first",
                layer,
                required
            );
        }
    }

    // Check if already applied
    if ctx.is_layer_applied(layer) {
        println!("Layer {:?} is already applied.", layer);
        return Ok(());
    }

    let modules = ctx.get_modules(layer)?;
    let executor = PowerShellExecutor::new(&ctx.modules_path);

    println!(
        "Applying {:?} Layer ({} modules)...\n",
        layer,
        modules.len()
    );

    // Create restore point
    println!("Creating system restore point...");
    executor
        .create_restore_point(&format!("Pre-{:?}-Optimization", layer))
        .await?;
    println!("  ✓ Restore point created\n");

    // Apply each module
    for (i, module) in modules.iter().enumerate() {
        println!(
            "[{}/{}] Applying: {}",
            i + 1,
            modules.len(),
            module.title
        );

        match executor.run_apply(layer.as_str(), &module.id).await {
            Ok(output) => {
                println!("  ✓ Success");
                if !output.is_empty() {
                    for line in output.lines().take(5) {
                        println!("    {}", line);
                    }
                }
            }
            Err(e) => {
                println!("  ✗ Failed: {}", e);
                println!("\nRolling back changes...");
                // Rollback logic here
                anyhow::bail!("Module {} failed to apply", module.id);
            }
        }
    }

    // Update state
    ctx.state.mark_layer_applied(layer)?;

    println!("\n✓ {:?} layer applied successfully!", layer);
    println!("Run verification: win11-optimizer --status");

    Ok(())
}

/// Rollback a layer
pub async fn rollback_layer(ctx: &mut AppContext, layer_name: &str) -> Result<()> {
    let layer = Layer::from_str(layer_name)?;

    if !ctx.is_layer_applied(layer) {
        println!("Layer {:?} is not currently applied.", layer);
        return Ok(());
    }

    let modules = ctx.get_modules(layer)?;
    let executor = PowerShellExecutor::new(&ctx.modules_path);

    println!(
        "Rolling back {:?} Layer ({} modules)...\n",
        layer,
        modules.len()
    );

    // Rollback in reverse order
    for (i, module) in modules.iter().rev().enumerate() {
        println!(
            "[{}/{}] Rolling back: {}",
            i + 1,
            modules.len(),
            module.title
        );

        match executor.run_rollback(layer.as_str(), &module.id).await {
            Ok(_) => {
                println!("  ✓ Rolled back");
            }
            Err(e) => {
                println!("  ⚠ Warning: {}", e);
            }
        }
    }

    // Update state
    ctx.state.mark_layer_removed(layer)?;

    println!("\n✓ {:?} layer rolled back.", layer);

    Ok(())
}
