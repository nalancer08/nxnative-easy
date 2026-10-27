//! Transfer only game content. Save roots are never read, removed or renamed.
use idevice::{
    IdeviceService,
    afc::{AfcClient, opcode::AfcFopenMode},
    house_arrest::HouseArrestClient,
    provider::UsbmuxdProvider,
};
use rootcause::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{
    io::Read,
    path::{Path, PathBuf},
    time::Instant,
};
// VendDocuments exposes /Documents within the app-container AFC namespace.
// This capability intentionally cannot address save roots or app preferences.
struct Documents(AfcClient);
fn remote(path: &str) -> Result<String, Report> {
    let first = path.split('/').next().unwrap_or("");
    if !(first == "romfs" || first.starts_with(".nxnative-romfs-"))
        || Path::new(path)
            .components()
            .any(|part| !matches!(part, std::path::Component::Normal(_)))
        || path.contains('\\')
    {
        bail!("Transfer path is outside game content")
    }
    Ok(format!("/Documents/{path}"))
}
impl Documents {
    async fn get_file_info(
        &mut self,
        path: impl AsRef<str>,
    ) -> Result<idevice::afc::FileInfo, Report> {
        Ok(self.0.get_file_info(remote(path.as_ref())?).await?)
    }
    async fn get_device_info(&mut self) -> Result<idevice::afc::DeviceInfo, Report> {
        Ok(self.0.get_device_info().await?)
    }
    async fn open(
        &mut self,
        path: impl AsRef<str>,
        mode: AfcFopenMode,
    ) -> Result<idevice::afc::file::FileDescriptor<'_>, Report> {
        Ok(self.0.open(remote(path.as_ref())?, mode).await?)
    }
    async fn mk_dir(&mut self, path: impl AsRef<str>) -> Result<(), Report> {
        Ok(self.0.mk_dir(remote(path.as_ref())?).await?)
    }
    async fn remove(&mut self, path: impl AsRef<str>) -> Result<(), Report> {
        Ok(self.0.remove(remote(path.as_ref())?).await?)
    }
    async fn remove_all(&mut self, path: impl AsRef<str>) -> Result<(), Report> {
        Ok(self.0.remove_all(remote(path.as_ref())?).await?)
    }
    async fn rename(
        &mut self,
        source: impl AsRef<str>,
        target: impl AsRef<str>,
    ) -> Result<(), Report> {
        Ok(self
            .0
            .rename(remote(source.as_ref())?, remote(target.as_ref())?)
            .await?)
    }
}
const JOURNAL: &str = ".nxnative-romfs-update.json";
#[derive(Serialize, Deserialize)]
struct Journal {
    stage: String,
    backup: String,
    complete: bool,
}
fn reserved(path: &str, kind: &str) -> bool {
    path.strip_prefix(&format!(".nxnative-romfs-{kind}-"))
        .is_some_and(|suffix| suffix.len() == 32 && suffix.chars().all(|c| c.is_ascii_hexdigit()))
}
#[derive(Debug, PartialEq)]
enum Recovery {
    Cleanup,
    Restore,
    DiscardStage,
}
fn recovery(complete: bool, backup_exists: bool) -> Recovery {
    if complete {
        Recovery::Cleanup
    } else if backup_exists {
        Recovery::Restore
    } else {
        Recovery::DiscardStage
    }
}
async fn exists(afc: &mut Documents, path: &str) -> bool {
    afc.get_file_info(path).await.is_ok()
}
async fn write(afc: &mut Documents, path: &str, data: &[u8]) -> Result<(), Report> {
    let mut file = afc.open(path, AfcFopenMode::WrOnly).await?;
    file.write_entire(data).await?;
    file.close().await?;
    Ok(())
}
async fn save_journal(afc: &mut Documents, journal: &Journal) -> Result<(), Report> {
    let next = format!("{JOURNAL}.next");
    write(afc, &next, &serde_json::to_vec(journal)?).await?;
    afc.rename(next, JOURNAL).await?;
    Ok(())
}
async fn recover(afc: &mut Documents) -> Result<(), Report> {
    if !exists(afc, JOURNAL).await {
        return Ok(());
    }
    if afc.get_file_info(JOURNAL).await?.size > 4096 {
        bail!("Invalid game-data recovery journal")
    }
    let mut file = afc.open(JOURNAL, AfcFopenMode::RdOnly).await?;
    let bytes = file.read_entire().await?;
    file.close().await?;
    if bytes.len() > 4096 {
        bail!("Invalid game-data recovery journal")
    }
    let mut journal: Journal = serde_json::from_slice(&bytes)?;
    if !reserved(&journal.stage, "stage") || !reserved(&journal.backup, "backup") {
        bail!("Unsafe game-data recovery journal")
    }
    let complete_path = journal.backup.clone() + "-complete";
    if exists(afc, &complete_path).await && afc.get_file_info(&complete_path).await?.size == 8 {
        let mut marker = afc.open(&complete_path, AfcFopenMode::RdOnly).await?;
        journal.complete = marker.read_entire().await? == b"complete";
        marker.close().await?;
    }
    match recovery(journal.complete, exists(afc, &journal.backup).await) {
        Recovery::Cleanup => {
            if exists(afc, &journal.backup).await {
                afc.remove_all(&journal.backup).await?;
            }
        }
        Recovery::Restore => {
            if exists(afc, "romfs").await {
                let discard = journal.stage.clone() + "-discard";
                afc.rename("romfs", &discard).await?;
                afc.rename(&journal.backup, "romfs").await?;
                afc.remove_all(discard).await?;
            } else {
                afc.rename(&journal.backup, "romfs").await?;
            }
        }
        Recovery::DiscardStage => {}
    }
    if exists(afc, &journal.stage).await {
        afc.remove_all(&journal.stage).await?;
    }
    let discard = journal.stage.clone() + "-discard";
    if exists(afc, &discard).await {
        afc.remove_all(discard).await?;
    }
    if exists(afc, &complete_path).await {
        afc.remove(&complete_path).await?;
    }
    afc.remove(JOURNAL).await?;
    Ok(())
}
struct Entry {
    relative: String,
    path: PathBuf,
    size: u64,
    modified: std::time::SystemTime,
    directory: bool,
}
fn inventory(root: &Path) -> Result<Vec<Entry>, Report> {
    if root.is_symlink() || !root.is_dir() || root.file_name().is_none_or(|n| n != "romfs") {
        bail!("Choose the prepared romfs directory")
    }
    let root = root.canonicalize()?;
    let mut pending = vec![root.clone()];
    let mut entries = Vec::new();
    while let Some(dir) = pending.pop() {
        for entry in std::fs::read_dir(dir)? {
            let path = entry?.path();
            let info = path.symlink_metadata()?;
            if info.file_type().is_symlink() || (!info.is_file() && !info.is_dir()) {
                bail!("Game content contains a link or special file")
            }
            let relative = path
                .strip_prefix(&root)?
                .to_str()
                .ok_or_else(|| report!("Unsupported game filename"))?
                .to_string();
            if relative.contains('\\') || relative.contains('\0') {
                bail!("Unsafe game filename")
            }
            entries.push(Entry {
                relative,
                path: path.clone(),
                size: info.len(),
                modified: info.modified()?,
                directory: info.is_dir(),
            });
            if info.is_dir() {
                pending.push(path)
            }
            if entries.len() > 1000000 {
                bail!("Too many game files")
            }
        }
    }
    entries.sort_by(|a, b| a.relative.cmp(&b.relative));
    Ok(entries)
}
pub async fn transfer(
    provider: &UsbmuxdProvider,
    effective: &str,
    root: &Path,
) -> Result<(), Report> {
    let entries = inventory(root)?;
    let total: u64 = entries
        .iter()
        .filter(|e| !e.directory)
        .map(|e| e.size)
        .sum();
    if total == 0 {
        bail!("Empty game content")
    }
    let house = HouseArrestClient::connect(provider).await?;
    let mut afc = Documents(house.vend_documents(effective).await?);
    recover(&mut afc).await?;
    let free = afc.get_device_info().await?.free_bytes as u64;
    if free < total + 64 * 1024 * 1024 {
        bail!("Not enough device storage to stage game content safely")
    }
    let nonce = uuid::Uuid::new_v4().simple().to_string();
    let journal = Journal {
        stage: format!(".nxnative-romfs-stage-{nonce}"),
        backup: format!(".nxnative-romfs-backup-{nonce}"),
        complete: false,
    };
    afc.mk_dir(&journal.stage).await?;
    save_journal(&mut afc, &journal).await?;
    let mut done = 0u64;
    let mut last = Instant::now();
    let mut buffer = vec![0u8; 1024 * 1024];
    for entry in entries {
        let target = format!("{}/{}", journal.stage, entry.relative);
        if entry.directory {
            afc.mk_dir(target).await?;
            continue;
        }
        let mut source = std::fs::File::open(&entry.path)?;
        let mut file = afc.open(&target, AfcFopenMode::WrOnly).await?;
        let mut written = 0u64;
        loop {
            let n = source.read(&mut buffer)?;
            if n == 0 {
                break;
            };
            file.write_entire(&buffer[..n]).await?;
            written += n as u64;
            done += n as u64;
            if last.elapsed().as_millis() >= 500 {
                crate::emit(
                    json!({"event":"progress","phase":"Copying game data","fraction":done as f64/total as f64,"done":done,"total":total}),
                );
                last = Instant::now();
            }
        }
        file.close().await?;
        let info = source.metadata()?;
        if written != entry.size
            || info.len() != entry.size
            || info.modified()? != entry.modified
            || afc.get_file_info(target).await?.size as u64 != written
        {
            bail!("Game files changed or transfer was incomplete")
        }
    }
    if exists(&mut afc, "romfs").await {
        afc.rename("romfs", &journal.backup).await?;
    }
    if let Err(error) = afc.rename(&journal.stage, "romfs").await {
        let _ = recover(&mut afc).await;
        return Err(error.into());
    }
    // A separate completion marker avoids replacing an existing journal over AFC.
    let complete_path = journal.backup.clone() + "-complete";
    write(&mut afc, &complete_path, b"complete").await?;
    if exists(&mut afc, &journal.backup).await {
        afc.remove_all(&journal.backup).await?;
    }
    afc.remove(&complete_path).await?;
    afc.remove(JOURNAL).await?;
    crate::emit(json!({"event":"progress","phase":"Game data ready","fraction":1.0}));
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn document_capability_cannot_access_saves() {
        assert_eq!(
            remote("romfs/data/file").unwrap(),
            "/Documents/romfs/data/file"
        );
        for name in [
            "save",
            "save_device",
            "/Documents/save",
            "romfs/../save",
            "Library/Preferences",
            "temp",
        ] {
            assert!(remote(name).is_err());
        }
        assert!(remote(JOURNAL).is_ok());
    }
    #[test]
    fn recovery_never_rolls_back_completed_content() {
        assert_eq!(recovery(true, true), Recovery::Cleanup);
        assert_eq!(recovery(false, true), Recovery::Restore);
        assert_eq!(recovery(false, false), Recovery::DiscardStage);
    }
    #[test]
    fn reserved_names_cannot_point_at_saves() {
        for name in [
            "save",
            "save_device",
            "../save",
            ".nxnative-romfs-backup-../../save",
        ] {
            assert!(!reserved(name, "backup"))
        }
        assert!(reserved(
            ".nxnative-romfs-backup-0123456789abcdef0123456789abcdef",
            "backup"
        ));
    }
    #[test]
    fn inventory_rejects_links() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().join("romfs");
        std::fs::create_dir(&root).unwrap();
        std::fs::write(root.join("data"), b"game").unwrap();
        assert_eq!(inventory(&root).unwrap().len(), 1);
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink("/tmp", root.join("link")).unwrap();
            assert!(inventory(&root).is_err());
        }
    }
}
