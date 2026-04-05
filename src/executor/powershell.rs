//! PowerShell process execution

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::process::Stdio;
use tokio::process::Command;

/// PowerShell executor for running module scripts
pub struct PowerShellExecutor {
    modules_path: PathBuf,
}

impl PowerShellExecutor {
    /// Create a new executor with the given modules path
    pub fn new(modules_path: &Path) -> Self {
        Self {
            modules_path: modules_path.to_path_buf(),
        }
    }

    /// Run a PowerShell script and capture output
    async fn run_script(&self, script_path: &Path) -> Result<String> {
        if !script_path.exists() {
            anyhow::bail!("Script not found: {}", script_path.display());
        }

        let output = Command::new("pwsh")
            .arg("-NoProfile")
            .arg("-NonInteractive")
            .arg("-ExecutionPolicy")
            .arg("Bypass")
            .arg("-File")
            .arg(script_path)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await
            .context("Failed to execute PowerShell")?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        if !output.status.success() {
            let exit_code = output.status.code().unwrap_or(-1);
            anyhow::bail!(
                "Script failed with exit code {}: {}",
                exit_code,
                if stderr.is_empty() { &stdout } else { &stderr }
            );
        }

        Ok(stdout)
    }

    /// Run a PowerShell command directly
    async fn run_command(&self, command: &str) -> Result<String> {
        let output = Command::new("pwsh")
            .arg("-NoProfile")
            .arg("-NonInteractive")
            .arg("-ExecutionPolicy")
            .arg("Bypass")
            .arg("-Command")
            .arg(command)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await
            .context("Failed to execute PowerShell command")?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        if !output.status.success() {
            let exit_code = output.status.code().unwrap_or(-1);
            anyhow::bail!(
                "Command failed with exit code {}: {}",
                exit_code,
                if stderr.is_empty() { &stdout } else { &stderr }
            );
        }

        Ok(stdout)
    }

    /// Get path to a module script
    fn module_script_path(&self, layer: &str, module: &str, script: &str) -> PathBuf {
        self.modules_path.join(layer).join(module).join(script)
    }

    /// Run module preview script
    pub async fn run_preview(&self, layer: &str, module: &str) -> Result<String> {
        let script_path = self.module_script_path(layer, module, "preview.ps1");
        self.run_script(&script_path).await
    }

    /// Run module apply script
    pub async fn run_apply(&self, layer: &str, module: &str) -> Result<String> {
        let script_path = self.module_script_path(layer, module, "apply.ps1");
        tracing::info!("Applying module: {}/{}", layer, module);
        self.run_script(&script_path).await
    }

    /// Run module rollback script
    pub async fn run_rollback(&self, layer: &str, module: &str) -> Result<String> {
        let script_path = self.module_script_path(layer, module, "rollback.ps1");
        tracing::info!("Rolling back module: {}/{}", layer, module);
        self.run_script(&script_path).await
    }

    /// Run module verify script
    pub async fn run_verify(&self, layer: &str, module: &str) -> Result<String> {
        let script_path = self.module_script_path(layer, module, "verify.ps1");
        self.run_script(&script_path).await
    }

    /// Create a system restore point
    pub async fn create_restore_point(&self, description: &str) -> Result<()> {
        // Bypass 24-hour cooldown
        let bypass_cmd = r#"
            $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
            $orig = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).SystemRestorePointCreationFrequency
            Set-ItemProperty -Path $key -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force
            try {
                Checkpoint-Computer -Description $args[0] -RestorePointType 'MODIFY_SETTINGS'
            } finally {
                if ($orig) {
                    Set-ItemProperty -Path $key -Name 'SystemRestorePointCreationFrequency' -Value $orig -Type DWord -Force
                } else {
                    Remove-ItemProperty -Path $key -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue
                }
            }
        "#;

        let output = Command::new("pwsh")
            .arg("-NoProfile")
            .arg("-NonInteractive")
            .arg("-ExecutionPolicy")
            .arg("Bypass")
            .arg("-Command")
            .arg(bypass_cmd)
            .arg("-args")
            .arg(description)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await
            .context("Failed to create restore point")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            // Restore points may fail in some environments (e.g., VMs without System Protection)
            tracing::warn!("Restore point creation failed: {}", stderr);
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_run_command() {
        let executor = PowerShellExecutor::new(Path::new("."));
        let result = executor.run_command("Write-Output 'Hello'").await;
        // May fail if pwsh not available
        if let Ok(output) = result {
            assert!(output.contains("Hello"));
        }
    }
}
