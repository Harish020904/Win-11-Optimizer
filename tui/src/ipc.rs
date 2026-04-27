use std::{
    fs::OpenOptions,
    io,
    path::{Path, PathBuf},
    process::Stdio,
};

use serde::{Deserialize, Serialize};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    process::{Child, ChildStdin, ChildStdout, Command},
};

use crate::app::{DisclaimerData, SystemMetrics, VerifyResult};

#[derive(Debug)]
pub enum IpcError {
    Io(io::Error),
    Json(serde_json::Error),
    Eof,
    MissingPipe(&'static str),
    BackendScriptNotFound(Vec<PathBuf>),
}

impl std::fmt::Display for IpcError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(err) => write!(f, "I/O error: {err}"),
            Self::Json(err) => write!(f, "JSON error: {err}"),
            Self::Eof => write!(f, "PowerShell closed stdout"),
            Self::MissingPipe(name) => write!(f, "PowerShell missing {name} pipe"),
            Self::BackendScriptNotFound(paths) => {
                write!(f, "WinOptimizer.ps1 not found. Tried: ")?;
                for (index, path) in paths.iter().enumerate() {
                    if index > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{}", path.display())?;
                }
                Ok(())
            }
        }
    }
}

impl std::error::Error for IpcError {}

impl From<io::Error> for IpcError {
    fn from(value: io::Error) -> Self {
        Self::Io(value)
    }
}

impl From<serde_json::Error> for IpcError {
    fn from(value: serde_json::Error) -> Self {
        Self::Json(value)
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
pub enum IpcCommand {
    GetStatus,
    GetState,
    ApplyLayer {
        layer: String,
        #[serde(rename = "dryRun")]
        dry_run: bool,
    },
    RollbackLayer {
        layer: String,
    },
    VerifySystem,
    Snapshot,
    Consent {
        decision: ConsentDecision,
    },
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ConsentDecision {
    Apply,
    Skip,
    RunAll,
    DryRun,
    Quit,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum IpcEvent {
    Progress {
        #[serde(rename = "tweakId")]
        tweak_id: u32,
        #[serde(default, rename = "tweakName")]
        tweak_name: String,
        message: String,
        #[serde(default)]
        state: String,
    },
    Done {
        layer: String,
        passed: bool,
    },
    Error {
        #[serde(rename = "tweakId")]
        tweak_id: u32,
        #[serde(default, rename = "tweakName")]
        tweak_name: String,
        message: String,
    },
    ConsentRequired(DisclaimerData),
    Status {
        metrics: SystemMetrics,
    },
    Verify(VerifyResult),
    State {
        state: serde_json::Value,
    },
    Log {
        message: String,
    },
}

pub async fn spawn_backend() -> Result<(Child, BufReader<ChildStdout>), IpcError> {
    let exe = if cfg!(windows) {
        "powershell.exe"
    } else {
        "pwsh"
    };
    let backend_script = locate_backend_script()?;
    let backend_dir = backend_script.parent().unwrap_or_else(|| Path::new("."));
    let stderr_path = backend_dir.join("win11-optimizer-tui.stderr.log");
    let stderr = OpenOptions::new()
        .create(true)
        .append(true)
        .open(stderr_path)?;

    let mut child = Command::new(exe)
        .arg("-NoProfile")
        .arg("-NonInteractive")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-File")
        .arg(&backend_script)
        .arg("--mode")
        .arg("ipc")
        .current_dir(backend_dir)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::from(stderr))
        .spawn()?;

    let stdout = child.stdout.take().ok_or(IpcError::MissingPipe("stdout"))?;
    Ok((child, BufReader::new(stdout)))
}

fn locate_backend_script() -> Result<PathBuf, IpcError> {
    let mut candidates = Vec::new();

    if let Ok(exe) = std::env::current_exe() {
        if let Some(exe_dir) = exe.parent() {
            candidates.push(exe_dir.join("WinOptimizer.ps1"));
        }
    }

    if let Ok(cwd) = std::env::current_dir() {
        candidates.push(cwd.join("WinOptimizer.ps1"));
        candidates.push(cwd.join("..").join("WinOptimizer.ps1"));
        candidates.push(cwd.join("..").join("..").join("WinOptimizer.ps1"));
    }

    for path in &candidates {
        if path.exists() {
            return Ok(path.clone());
        }
    }

    Err(IpcError::BackendScriptNotFound(candidates))
}

pub async fn send_command(child: &mut Child, cmd: IpcCommand) -> Result<(), IpcError> {
    let stdin = child.stdin.as_mut().ok_or(IpcError::MissingPipe("stdin"))?;
    send_command_to_stdin(stdin, cmd).await
}

pub async fn send_command_to_stdin(
    stdin: &mut ChildStdin,
    cmd: IpcCommand,
) -> Result<(), IpcError> {
    let json = serde_json::to_string(&cmd)?;
    stdin.write_all(json.as_bytes()).await?;
    stdin.write_all(b"\n").await?;
    stdin.flush().await?;
    Ok(())
}

pub async fn read_event(reader: &mut BufReader<ChildStdout>) -> Result<IpcEvent, IpcError> {
    let mut line = String::new();
    let bytes = reader.read_line(&mut line).await?;
    if bytes == 0 {
        return Err(IpcError::Eof);
    }
    let event = serde_json::from_str(line.trim())?;
    Ok(event)
}
