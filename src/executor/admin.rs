//! Administrator privilege detection and elevation

#[cfg(windows)]
use windows::Win32::Security::{GetTokenInformation, TokenElevation, TOKEN_ELEVATION, TOKEN_QUERY};
#[cfg(windows)]
use windows::Win32::System::Threading::{GetCurrentProcess, OpenProcessToken};

/// Check if the current process is running with administrator privileges
#[cfg(windows)]
pub fn is_elevated() -> bool {
    use std::mem::MaybeUninit;

    unsafe {
        let mut token_handle = windows::Win32::Foundation::HANDLE::default();

        // Open the current process token
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token_handle).is_err() {
            return false;
        }

        let mut elevation = MaybeUninit::<TOKEN_ELEVATION>::uninit();
        let mut size = std::mem::size_of::<TOKEN_ELEVATION>() as u32;

        // Get token elevation information
        let result = GetTokenInformation(
            token_handle,
            TokenElevation,
            Some(elevation.as_mut_ptr() as *mut _),
            size,
            &mut size,
        );

        if result.is_err() {
            return false;
        }

        let elevation = elevation.assume_init();
        elevation.TokenIsElevated != 0
    }
}

/// Stub for non-Windows platforms (always returns true for testing)
#[cfg(not(windows))]
pub fn is_elevated() -> bool {
    // On non-Windows, assume elevated for development/testing
    true
}

/// Request elevation via UAC dialog
#[cfg(windows)]
pub fn request_elevation() -> anyhow::Result<()> {
    use std::os::windows::ffi::OsStrExt;
    use std::ffi::OsStr;
    use windows::Win32::UI::Shell::ShellExecuteW;
    use windows::core::PCWSTR;

    let exe_path = std::env::current_exe()?;
    let exe_path_wide: Vec<u16> = OsStr::new(exe_path.as_os_str())
        .encode_wide()
        .chain(std::iter::once(0))
        .collect();

    let verb: Vec<u16> = OsStr::new("runas")
        .encode_wide()
        .chain(std::iter::once(0))
        .collect();

    unsafe {
        ShellExecuteW(
            None,
            PCWSTR::from_raw(verb.as_ptr()),
            PCWSTR::from_raw(exe_path_wide.as_ptr()),
            PCWSTR::null(),
            PCWSTR::null(),
            windows::Win32::UI::WindowsAndMessaging::SW_SHOWNORMAL,
        );
    }

    // Exit current non-elevated process
    std::process::exit(0);
}

#[cfg(not(windows))]
pub fn request_elevation() -> anyhow::Result<()> {
    anyhow::bail!("Elevation is only supported on Windows")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_elevated() {
        // Just ensure it doesn't panic
        let _ = is_elevated();
    }
}
