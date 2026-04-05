//! Protected Windows components that must never be modified

/// List of protected Windows services that must never be disabled or modified
pub const PROTECTED_SERVICES: &[&str] = &[
    // Core System
    "TrustedInstaller",
    "wuauserv",      // Windows Update
    "WaaSMedicSvc",  // Windows Update Medic
    "UsoSvc",        // Update Orchestrator
    
    // Security
    "WinDefend",     // Windows Defender
    "WdNisSvc",      // Defender Network Inspection
    "SecurityHealthService",
    "wscsvc",        // Security Center
    "SamSs",         // Security Accounts Manager
    "VaultSvc",      // Credential Manager
    
    // Core Services
    "RpcSs",         // RPC
    "RpcEptMapper",
    "DcomLaunch",
    "LSM",           // Local Session Manager
    "LanmanServer",
    "LanmanWorkstation",
    "Netlogon",
    "PlugPlay",      // Plug and Play
    "Power",
    "ProfSvc",       // User Profile Service
    "Schedule",      // Task Scheduler
    "EventLog",
    "EventSystem",
    
    // Networking
    "Dnscache",
    "Dhcp",
    "NlaSvc",        // Network Location Awareness
    "nsi",           // Network Store Interface
    "Tcpip",
    "WinHttpAutoProxySvc",
    
    // Storage
    "VSS",           // Volume Shadow Copy
    "StorSvc",       // Storage Service
    "stisvc",        // Windows Image Acquisition
    
    // Shell
    "ShellHWDetection",
    "Themes",
    "UxSms",         // Desktop Window Manager
    "DWM",
    
    // Critical Infrastructure
    "CryptSvc",      // Cryptographic Services
    "AppIDSvc",      // Application Identity
    "BFE",           // Base Filtering Engine
    "mpssvc",        // Windows Firewall
    "WdiServiceHost",
    "WdiSystemHost",
];

/// List of protected registry paths
pub const PROTECTED_REGISTRY_PATHS: &[&str] = &[
    r"HKLM\SYSTEM\CurrentControlSet\Services\TrustedInstaller",
    r"HKLM\SYSTEM\CurrentControlSet\Services\WinDefend",
    r"HKLM\SYSTEM\CurrentControlSet\Services\wuauserv",
    r"HKLM\SOFTWARE\Microsoft\Windows Defender",
    r"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing",
];

/// Check if a service name is protected
pub fn is_protected_service(name: &str) -> bool {
    PROTECTED_SERVICES
        .iter()
        .any(|&s| s.eq_ignore_ascii_case(name))
}

/// Check if a registry path is protected
pub fn is_protected_registry(path: &str) -> bool {
    PROTECTED_REGISTRY_PATHS
        .iter()
        .any(|&p| path.to_lowercase().starts_with(&p.to_lowercase()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_protected_service() {
        assert!(is_protected_service("WinDefend"));
        assert!(is_protected_service("windefend"));
        assert!(!is_protected_service("DiagTrack"));
    }

    #[test]
    fn test_protected_registry() {
        assert!(is_protected_registry(r"HKLM\SOFTWARE\Microsoft\Windows Defender\Features"));
        assert!(!is_protected_registry(r"HKCU\Software\MyApp"));
    }
}
