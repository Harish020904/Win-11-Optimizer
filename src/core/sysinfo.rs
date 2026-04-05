//! System information gathering for Windows
//! Provides comprehensive system insights similar to fastfetch/neofetch

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::process::Command;

/// Comprehensive system information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemInfo {
    /// OS version and build
    pub os_version: String,
    /// Windows edition (Home, Pro, Enterprise, etc.)
    pub os_edition: String,
    /// System build number
    pub build_number: String,
    /// CPU model
    pub cpu_model: String,
    /// CPU cores
    pub cpu_cores: u32,
    /// Total RAM in GB
    pub total_ram_gb: f64,
    /// Available RAM in GB
    pub available_ram_gb: f64,
    /// GPU information
    pub gpu: String,
    /// Disk information (C: drive)
    pub disk_total_gb: f64,
    /// Disk used in GB
    pub disk_used_gb: f64,
    /// Disk free in GB
    pub disk_free_gb: f64,
    /// System uptime
    pub uptime: String,
    /// Hostname
    pub hostname: String,
    /// Username
    pub username: String,
}

/// Storage cleanup estimation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanupEstimate {
    /// Temp files size in GB
    pub temp_files_gb: f64,
    /// Windows Update cache in GB
    pub update_cache_gb: f64,
    /// Recycle Bin size in GB
    pub recycle_bin_gb: f64,
    /// Prefetch files in GB
    pub prefetch_gb: f64,
    /// Windows old installations in GB
    pub windows_old_gb: f64,
    /// Downloaded installers in GB
    pub downloads_gb: f64,
    /// Total estimated cleanup in GB
    pub total_cleanup_gb: f64,
}

impl SystemInfo {
    /// Gather comprehensive system information
    pub fn gather() -> Result<Self> {
        #[cfg(target_os = "windows")]
        {
            Self::gather_windows()
        }
        #[cfg(not(target_os = "windows"))]
        {
            Self::gather_mock()
        }
    }

    #[cfg(target_os = "windows")]
    fn gather_windows() -> Result<Self> {
        // Get OS information
        let os_version = Self::get_wmic_value("os", "Caption")?;
        let os_edition = Self::get_wmic_value("os", "OperatingSystemSKU")?;
        let build_number = Self::get_wmic_value("os", "BuildNumber")?;
        
        // Get CPU information
        let cpu_model = Self::get_wmic_value("cpu", "Name")?;
        let cpu_cores_str = Self::get_wmic_value("cpu", "NumberOfCores")?;
        let cpu_cores = cpu_cores_str.trim().parse::<u32>().unwrap_or(0);
        
        // Get memory information
        let total_mem_str = Self::get_wmic_value("computersystem", "TotalPhysicalMemory")?;
        let total_mem_bytes = total_mem_str.trim().parse::<u64>().unwrap_or(0);
        let total_ram_gb = total_mem_bytes as f64 / (1024.0 * 1024.0 * 1024.0);
        
        // Get available memory using PowerShell
        let available_ram_gb = Self::get_available_memory_gb()?;
        
        // Get GPU information
        let gpu = Self::get_wmic_value("path win32_VideoController", "Name")
            .unwrap_or_else(|_| "Unknown GPU".to_string());
        
        // Get disk information
        let (disk_total_gb, disk_free_gb) = Self::get_disk_info()?;
        let disk_used_gb = disk_total_gb - disk_free_gb;
        
        // Get uptime
        let uptime = Self::get_uptime()?;
        
        // Get hostname and username
        let hostname = std::env::var("COMPUTERNAME").unwrap_or_else(|_| "Unknown".to_string());
        let username = std::env::var("USERNAME").unwrap_or_else(|_| "Unknown".to_string());
        
        Ok(Self {
            os_version,
            os_edition,
            build_number,
            cpu_model,
            cpu_cores,
            total_ram_gb,
            available_ram_gb,
            gpu,
            disk_total_gb,
            disk_used_gb,
            disk_free_gb,
            uptime,
            hostname,
            username,
        })
    }

    #[cfg(not(target_os = "windows"))]
    fn gather_mock() -> Result<Self> {
        Ok(Self {
            os_version: "Windows 11 Pro (Mock)".to_string(),
            os_edition: "Pro".to_string(),
            build_number: "22631".to_string(),
            cpu_model: "Intel Core i7-12700K".to_string(),
            cpu_cores: 12,
            total_ram_gb: 32.0,
            available_ram_gb: 16.5,
            gpu: "NVIDIA GeForce RTX 4070".to_string(),
            disk_total_gb: 1000.0,
            disk_used_gb: 450.0,
            disk_free_gb: 550.0,
            uptime: "5 hours, 23 minutes".to_string(),
            hostname: std::env::var("HOSTNAME").unwrap_or_else(|_| "PC-MOCK".to_string()),
            username: std::env::var("USER").unwrap_or_else(|_| "user".to_string()),
        })
    }

    #[cfg(target_os = "windows")]
    fn get_wmic_value(class: &str, property: &str) -> Result<String> {
        let output = Command::new("wmic")
            .args([class, "get", property, "/value"])
            .output()?;
        
        let output_str = String::from_utf8_lossy(&output.stdout);
        for line in output_str.lines() {
            if line.contains('=') {
                let parts: Vec<&str> = line.split('=').collect();
                if parts.len() >= 2 {
                    return Ok(parts[1].trim().to_string());
                }
            }
        }
        Ok("Unknown".to_string())
    }

    #[cfg(target_os = "windows")]
    fn get_available_memory_gb() -> Result<f64> {
        let output = Command::new("powershell")
            .args(["-Command", "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"])
            .output()?;
        
        let kb_str = String::from_utf8_lossy(&output.stdout);
        let kb = kb_str.trim().parse::<u64>().unwrap_or(0);
        Ok(kb as f64 / (1024.0 * 1024.0))
    }

    #[cfg(target_os = "windows")]
    fn get_disk_info() -> Result<(f64, f64)> {
        let output = Command::new("powershell")
            .args(["-Command", 
                "(Get-PSDrive C | Select-Object Used,Free | ConvertTo-Json -Compress)"])
            .output()?;
        
        let json_str = String::from_utf8_lossy(&output.stdout);
        
        // Simple parsing
        if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&json_str) {
            let used = parsed["Used"].as_f64().unwrap_or(0.0) / (1024.0 * 1024.0 * 1024.0);
            let free = parsed["Free"].as_f64().unwrap_or(0.0) / (1024.0 * 1024.0 * 1024.0);
            return Ok((used + free, free));
        }
        
        Ok((1000.0, 500.0))
    }

    #[cfg(target_os = "windows")]
    fn get_uptime() -> Result<String> {
        let output = Command::new("powershell")
            .args(["-Command", 
                "((Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime).ToString('hh\\:mm\\:ss')"])
            .output()?;
        
        let uptime_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(uptime_str)
    }
}

impl CleanupEstimate {
    /// Calculate storage cleanup estimation
    pub fn calculate() -> Result<Self> {
        #[cfg(target_os = "windows")]
        {
            Self::calculate_windows()
        }
        #[cfg(not(target_os = "windows"))]
        {
            Self::calculate_mock()
        }
    }

    #[cfg(target_os = "windows")]
    fn calculate_windows() -> Result<Self> {
        let temp_files_gb = Self::get_folder_size("C:\\Windows\\Temp")?
            + Self::get_folder_size(&format!("{}\\AppData\\Local\\Temp", 
                std::env::var("USERPROFILE").unwrap_or_default()))?;
        
        let update_cache_gb = Self::get_folder_size("C:\\Windows\\SoftwareDistribution\\Download")?;
        
        let recycle_bin_gb = Self::get_folder_size("C:\\$Recycle.Bin")?;
        
        let prefetch_gb = Self::get_folder_size("C:\\Windows\\Prefetch")?;
        
        let windows_old_gb = Self::get_folder_size("C:\\Windows.old")?;
        
        let downloads_gb = Self::get_folder_size(&format!("{}\\Downloads", 
            std::env::var("USERPROFILE").unwrap_or_default()))?;
        
        let total_cleanup_gb = temp_files_gb + update_cache_gb + recycle_bin_gb 
            + prefetch_gb + windows_old_gb;
        
        Ok(Self {
            temp_files_gb,
            update_cache_gb,
            recycle_bin_gb,
            prefetch_gb,
            windows_old_gb,
            downloads_gb,
            total_cleanup_gb,
        })
    }

    #[cfg(not(target_os = "windows"))]
    fn calculate_mock() -> Result<Self> {
        Ok(Self {
            temp_files_gb: 2.5,
            update_cache_gb: 5.8,
            recycle_bin_gb: 1.2,
            prefetch_gb: 0.3,
            windows_old_gb: 0.0,
            downloads_gb: 8.7,
            total_cleanup_gb: 9.8,
        })
    }

    #[cfg(target_os = "windows")]
    fn get_folder_size(path: &str) -> Result<f64> {
        let ps_script = format!(
            "$size = (Get-ChildItem -Path '{}' -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; if ($size) {{ $size }} else {{ 0 }}",
            path
        );
        
        let output = Command::new("powershell")
            .args(["-Command", &ps_script])
            .output();
        
        if let Ok(out) = output {
            let size_str = String::from_utf8_lossy(&out.stdout);
            let bytes = size_str.trim().parse::<u64>().unwrap_or(0);
            return Ok(bytes as f64 / (1024.0 * 1024.0 * 1024.0));
        }
        
        Ok(0.0)
    }
}

/// Format bytes to human-readable string
pub fn format_bytes(bytes: f64) -> String {
    if bytes >= 1024.0 * 1024.0 * 1024.0 {
        format!("{:.2} GB", bytes / (1024.0 * 1024.0 * 1024.0))
    } else if bytes >= 1024.0 * 1024.0 {
        format!("{:.2} MB", bytes / (1024.0 * 1024.0))
    } else if bytes >= 1024.0 {
        format!("{:.2} KB", bytes / 1024.0)
    } else {
        format!("{:.0} B", bytes)
    }
}

/// Format disk usage percentage
pub fn format_disk_usage(used: f64, total: f64) -> String {
    if total > 0.0 {
        format!("{:.1}%", (used / total) * 100.0)
    } else {
        "N/A".to_string()
    }
}
