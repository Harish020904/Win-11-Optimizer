//! System snapshot management

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Snapshot metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    /// Unique snapshot ID
    pub id: String,
    /// Timestamp of snapshot creation
    pub created_at: DateTime<Utc>,
    /// Description/reason for snapshot
    pub description: String,
    /// Path to snapshot data
    pub path: PathBuf,
    /// Associated layer (if any)
    pub layer: Option<String>,
}

/// Snapshot manager for backup/restore operations
pub struct SnapshotManager {
    backup_root: PathBuf,
}

impl SnapshotManager {
    /// Create a new snapshot manager
    pub fn new() -> Result<Self> {
        let backup_root = PathBuf::from(r"C:\ProgramData\WinOptimizer\backup");
        std::fs::create_dir_all(&backup_root)?;
        Ok(Self { backup_root })
    }

    /// Create a new snapshot directory for a layer
    pub fn create_snapshot_dir(&self, layer: &str) -> Result<PathBuf> {
        let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
        let snapshot_name = format!("{}_{}", timestamp, layer);
        let snapshot_path = self.backup_root.join(&snapshot_name);
        std::fs::create_dir_all(&snapshot_path)?;
        Ok(snapshot_path)
    }

    /// Get the latest snapshot for a layer
    pub fn get_latest_snapshot(&self, layer: &str) -> Result<Option<PathBuf>> {
        let entries: Vec<_> = std::fs::read_dir(&self.backup_root)?
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_string_lossy()
                    .ends_with(&format!("_{}", layer))
            })
            .collect();

        let latest = entries
            .iter()
            .max_by_key(|e| e.file_name())
            .map(|e| e.path());

        Ok(latest)
    }

    /// List all snapshots
    pub fn list_snapshots(&self) -> Result<Vec<Snapshot>> {
        let mut snapshots = Vec::new();

        for entry in std::fs::read_dir(&self.backup_root)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let name = entry.file_name().to_string_lossy().to_string();

                // Parse timestamp and layer from directory name
                let parts: Vec<&str> = name.splitn(3, '_').collect();
                if parts.len() >= 2 {
                    let layer = parts.get(2).map(|s| s.to_string());

                    snapshots.push(Snapshot {
                        id: name.clone(),
                        created_at: Utc::now(), // TODO: Parse from name
                        description: format!("Snapshot {}", name),
                        path: path.clone(),
                        layer,
                    });
                }
            }
        }

        // Sort by ID (timestamp) descending
        snapshots.sort_by(|a, b| b.id.cmp(&a.id));

        Ok(snapshots)
    }

    /// Delete old snapshots, keeping only the N most recent per layer
    pub fn cleanup(&self, keep_per_layer: usize) -> Result<usize> {
        let snapshots = self.list_snapshots()?;
        let mut deleted = 0;

        // Group by layer
        let mut by_layer: std::collections::HashMap<Option<String>, Vec<&Snapshot>> =
            std::collections::HashMap::new();

        for snapshot in &snapshots {
            by_layer
                .entry(snapshot.layer.clone())
                .or_default()
                .push(snapshot);
        }

        // Delete old snapshots beyond keep limit
        for (_layer, mut layer_snapshots) in by_layer {
            layer_snapshots.sort_by(|a, b| b.id.cmp(&a.id));

            for snapshot in layer_snapshots.into_iter().skip(keep_per_layer) {
                if std::fs::remove_dir_all(&snapshot.path).is_ok() {
                    deleted += 1;
                    tracing::info!("Deleted old snapshot: {}", snapshot.id);
                }
            }
        }

        Ok(deleted)
    }
}

// CODE-003: Removed Default impl that used expect() - callers must handle
// SnapshotManager::new() Result explicitly to avoid panics
