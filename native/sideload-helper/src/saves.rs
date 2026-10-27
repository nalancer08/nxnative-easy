//! Read-only committed-save export. This module has no device write/delete operation.
use idevice::{
    IdeviceError, IdeviceService,
    afc::{AfcClient, errors::AfcError, opcode::AfcFopenMode},
    house_arrest::HouseArrestClient,
};
use rootcause::prelude::*;
use serde::Serialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    io::Write,
    path::{Component, Path},
    time::{SystemTime, UNIX_EPOCH},
};
use zip::{ZipWriter, write::SimpleFileOptions};
const MAX_BYTES: u64 = 512 * 1024 * 1024;
const MAX_ENTRIES: usize = 8192;
fn remote(path: &str) -> Result<String, Report> {
    let parts: Vec<_> = path.split('/').collect();
    if !matches!(parts.first(), Some(&"save" | &"save_device"))
        || parts.len() > 32
        || path.len() > 1024
        || path.contains(['\\', ':', '\0'])
        || Path::new(path)
            .components()
            .any(|c| !matches!(c, Component::Normal(_)))
        || parts
            .iter()
            .any(|p| p.is_empty() || *p == "." || *p == ".." || p.starts_with(".dm-case-"))
    {
        bail!("Unsupported save metadata or unsafe path")
    }
    for part in &parts {
        let lower = part.to_ascii_lowercase();
        if matches!(lower.as_str(), "prod.keys" | "title.keys")
            || Path::new(&lower)
                .extension()
                .and_then(|v| v.to_str())
                .is_some_and(|v| {
                    matches!(
                        v,
                        "p12" | "mobileprovision" | "ipa" | "nsp" | "xci" | "nsz" | "xcz"
                    )
                })
        {
            bail!("Unsupported save metadata or credential file")
        }
    }
    Ok(format!("/Documents/{path}"))
}
#[derive(Clone, Debug, PartialEq, Eq)]
struct Entry {
    path: String,
    size: u64,
    directory: bool,
    modified: String,
    created: String,
}
struct SaveReader(AfcClient);
impl SaveReader {
    async fn stat(&mut self, path: &str) -> Result<Option<Entry>, Report> {
        let info = match self.0.get_file_info_raw(remote(path)?).await {
            Ok(info) => info,
            Err(IdeviceError::Afc(AfcError::ObjectNotFound)) => return Ok(None),
            Err(error) => return Err(error.into()),
        };
        let kind = info.get("st_ifmt").map(String::as_str).unwrap_or("");
        if !matches!(kind, "S_IFREG" | "S_IFDIR") || info.contains_key("st_link_target") {
            bail!("Unsupported save metadata or special file")
        }
        Ok(Some(Entry {
            path: path.into(),
            size: info
                .get("st_size")
                .and_then(|v| v.parse().ok())
                .ok_or_else(|| report!("Missing save metadata"))?,
            directory: kind == "S_IFDIR",
            modified: info
                .get("st_mtime")
                .cloned()
                .ok_or_else(|| report!("Missing save metadata"))?,
            created: info.get("st_birthtime").cloned().unwrap_or_default(),
        }))
    }
    async fn inventory(&mut self) -> Result<Vec<Entry>, Report> {
        let mut pending = vec!["save".to_string(), "save_device".to_string()];
        let mut entries = Vec::new();
        let mut total = 0u64;
        while let Some(path) = pending.pop() {
            let Some(entry) = self.stat(&path).await? else {
                if path == "save" || path == "save_device" {
                    continue;
                } else {
                    bail!("Save changed during export")
                }
            };
            if entry.directory {
                for name in self.0.list_dir(remote(&path)?).await? {
                    if name == "." || name == ".." {
                        continue;
                    }
                    if name.contains('/') {
                        bail!("Unsafe save entry")
                    }
                    let child = format!("{path}/{name}");
                    remote(&child)?;
                    pending.push(child);
                }
            } else {
                total = total
                    .checked_add(entry.size)
                    .ok_or_else(|| report!("Save export exceeds limits"))?;
            }
            entries.push(entry);
            if entries.len() + pending.len() > MAX_ENTRIES || total > MAX_BYTES {
                bail!("Save export exceeds limits")
            }
        }
        entries.sort_by(|a, b| a.path.cmp(&b.path));
        Ok(entries)
    }
    async fn read(
        &mut self,
        entry: &Entry,
        mut output: Option<&mut ZipWriter<&mut std::fs::File>>,
    ) -> Result<String, Report> {
        let mut file = self
            .0
            .open(remote(&entry.path)?, AfcFopenMode::RdOnly)
            .await?;
        let mut remaining = entry.size;
        let mut hash = Sha256::new();
        while remaining > 0 {
            let bytes = file.read_n(remaining.min(1024 * 1024) as usize).await?;
            if bytes.is_empty() || bytes.len() as u64 > remaining {
                bail!("Save changed during export")
            }
            hash.update(&bytes);
            if let Some(writer) = output.as_mut() {
                writer.write_all(&bytes)?;
            }
            remaining -= bytes.len() as u64;
        }
        file.close().await?;
        Ok(hex::encode(hash.finalize()))
    }
}
#[derive(Serialize)]
struct Record {
    path: String,
    directory: bool,
    size: u64,
    sha256: Option<String>,
    modified_ns: String,
    created_ns: String,
}
fn publish(temporary: tempfile::NamedTempFile, destination: &Path) -> Result<(), Report> {
    temporary.as_file().sync_all()?;
    temporary
        .persist_noclobber(destination)
        .map_err(|_| report!("Save destination exists or cannot be created"))?;
    Ok(())
}
pub async fn export(
    udid: &str,
    effective: &str,
    scope: &super::games::Scope,
    destination: &Path,
    confirmed_closed: bool,
) -> Result<(), Report> {
    let games = super::games::installed(udid, scope).await?;
    let game = games
        .iter()
        .find(|g| g["id"].as_str() == Some(effective))
        .ok_or_else(|| report!("Existing app identity was not found"))?;
    super::require_closed(udid, game, confirmed_closed)?;
    let provider = super::provider(udid).await?;
    let house = HouseArrestClient::connect(&provider).await?;
    let mut reader = SaveReader(house.vend_documents(effective).await?);
    write_snapshot(&mut reader, effective, game, destination, confirmed_closed).await
}
trait CommittedSource {
    async fn entries(&mut self) -> Result<Vec<Entry>, Report>;
    async fn hash_to(
        &mut self,
        entry: &Entry,
        output: Option<&mut ZipWriter<&mut std::fs::File>>,
    ) -> Result<String, Report>;
}
impl CommittedSource for SaveReader {
    async fn entries(&mut self) -> Result<Vec<Entry>, Report> {
        self.inventory().await
    }
    async fn hash_to(
        &mut self,
        entry: &Entry,
        output: Option<&mut ZipWriter<&mut std::fs::File>>,
    ) -> Result<String, Report> {
        self.read(entry, output).await
    }
}
async fn write_snapshot(
    reader: &mut impl CommittedSource,
    effective: &str,
    game: &Value,
    destination: &Path,
    confirmed_closed: bool,
) -> Result<(), Report> {
    if destination.extension().and_then(|v| v.to_str()) != Some("zip")
        || destination.exists()
        || destination.symlink_metadata().is_ok()
    {
        bail!("Save destination exists or is not a new ZIP")
    }
    let parent = destination
        .parent()
        .filter(|p| p.is_dir())
        .ok_or_else(|| report!("Choose an existing destination folder"))?;
    if parent
        .canonicalize()?
        .ancestors()
        .any(|p| p.join(".git").exists())
    {
        bail!("Save destination must be outside source repositories")
    }

    let before = reader.entries().await?;
    if !before.iter().any(|e| !e.directory) {
        bail!("No committed save files found")
    }
    let unique: std::collections::BTreeSet<_> = before.iter().map(|e| e.path.as_str()).collect();
    if unique.len() != before.len() || before.len() > MAX_ENTRIES {
        bail!("Unsupported save metadata or duplicate paths")
    }
    for entry in &before {
        remote(&entry.path)?;
    }
    let total: u64 = before.iter().filter(|e| !e.directory).map(|e| e.size).sum();
    if total > MAX_BYTES {
        bail!("Save export exceeds limits")
    }
    let mut done = 0u64;
    let mut records = Vec::new();
    let mut temporary = tempfile::Builder::new()
        .prefix(".nxnative-save-export-")
        .tempfile_in(parent)?;
    let options = SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .unix_permissions(0o600);
    {
        let mut zip = ZipWriter::new(temporary.as_file_mut());
        for entry in &before {
            if entry.directory {
                zip.add_directory(entry.path.clone() + "/", options.unix_permissions(0o700))?;
                records.push(Record {
                    path: entry.path.clone(),
                    directory: true,
                    size: 0,
                    sha256: None,
                    modified_ns: entry.modified.clone(),
                    created_ns: entry.created.clone(),
                });
            } else {
                zip.start_file(&entry.path, options)?;
                let sha = reader.hash_to(entry, Some(&mut zip)).await?;
                done += entry.size;
                records.push(Record {
                    path: entry.path.clone(),
                    directory: false,
                    size: entry.size,
                    sha256: Some(sha),
                    modified_ns: entry.modified.clone(),
                    created_ns: entry.created.clone(),
                });
                super::emit(
                    json!({"event":"progress","phase":"Exporting saves","fraction":if total==0 {0.5}else{done as f64/total as f64*0.5}}),
                );
            }
        }
        super::emit(json!({"event":"progress","phase":"Verifying saves"}));
        if reader.entries().await? != before {
            bail!("Save changed during export")
        }
        for (entry, record) in before.iter().zip(&records) {
            if !entry.directory && Some(reader.hash_to(entry, None).await?) != record.sha256 {
                bail!("Save changed during export")
            }
        }
        if reader.entries().await? != before {
            bail!("Save changed during export")
        }
        zip.start_file("nxnative-save-export.json", options)?;
        let manifest = json!({"schema":1,"format":"nxnative-committed-save-export","bundle_id":effective,"game_version":game["version"],"created_unix":SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),"manual_closed_confirmation":confirmed_closed,"entries":records,"restoration":"manual; game/version/device compatibility must be checked"});
        zip.write_all(&serde_json::to_vec_pretty(&manifest)?)?;
        zip.finish()?;
    }
    publish(temporary, destination)?;
    super::emit(
        json!({"event":"saves_exported","path":destination,"files":records.iter().filter(|e|!e.directory).count(),"bytes":total}),
    );
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn save_reader_cannot_address_game_content_or_transactions() {
        for path in ["save", "save/profile/file.bin", "save_device/settings"] {
            assert!(remote(path).is_ok())
        }
        for path in [
            "romfs/file",
            "save.work/file",
            "save.new/file",
            "save_device.work/file",
            "save/../romfs",
            "/Documents/save",
            "save//file",
            "save/link\\file",
            "save/.dm-case-alias",
            "save/prod.keys",
            "save/private.p12",
            "save/./file",
        ] {
            assert!(remote(path).is_err(), "{path}")
        }
    }
    #[test]
    fn export_publication_never_overwrites_a_backup() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("save.zip");
        std::fs::write(&path, b"keep").unwrap();
        let mut temporary = tempfile::NamedTempFile::new_in(root.path()).unwrap();
        temporary.write_all(b"new").unwrap();
        assert!(publish(temporary, &path).is_err());
        assert_eq!(std::fs::read(&path).unwrap(), b"keep");
    }
    struct Memory {
        bytes: Vec<u8>,
        reads: usize,
        change: bool,
    }
    impl CommittedSource for Memory {
        async fn entries(&mut self) -> Result<Vec<Entry>, Report> {
            Ok(vec![
                Entry {
                    path: "save".into(),
                    size: 0,
                    directory: true,
                    modified: "same".into(),
                    created: "same".into(),
                },
                Entry {
                    path: "save/progress.dat".into(),
                    size: self.bytes.len() as u64,
                    directory: false,
                    modified: "same".into(),
                    created: "same".into(),
                },
            ])
        }
        async fn hash_to(
            &mut self,
            _entry: &Entry,
            output: Option<&mut ZipWriter<&mut std::fs::File>>,
        ) -> Result<String, Report> {
            let mut bytes = self.bytes.clone();
            if self.change && self.reads > 0 {
                bytes[0] ^= 1
            };
            self.reads += 1;
            if let Some(writer) = output {
                writer.write_all(&bytes)?
            }
            Ok(hex::encode(Sha256::digest(&bytes)))
        }
    }
    #[tokio::test]
    async fn actual_zip_roundtrip_and_manifest_preserve_save_bytes() {
        use std::io::Read;
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("saved.zip");
        let bytes = b"synthetic committed progress".to_vec();
        let mut source = Memory {
            bytes: bytes.clone(),
            reads: 0,
            change: false,
        };
        write_snapshot(
            &mut source,
            "org.synthetic.game",
            &json!({"version":"2.1.0"}),
            &path,
            true,
        )
        .await
        .unwrap();
        let mut archive = zip::ZipArchive::new(std::fs::File::open(&path).unwrap()).unwrap();
        let mut restored = Vec::new();
        archive
            .by_name("save/progress.dat")
            .unwrap()
            .read_to_end(&mut restored)
            .unwrap();
        assert_eq!(restored, bytes);
        let manifest: Value =
            serde_json::from_reader(archive.by_name("nxnative-save-export.json").unwrap()).unwrap();
        assert_eq!(
            archive.by_name("save/").unwrap().unix_mode().unwrap() & 0o777,
            0o700
        );
        assert_eq!(
            manifest["entries"][1]["sha256"],
            hex::encode(Sha256::digest(&bytes))
        );
        assert_eq!(
            std::fs::metadata(path).unwrap().permissions().mode() & 0o777,
            0o600
        );
        assert_eq!(source.bytes, bytes);
    }
    #[tokio::test]
    async fn changing_source_never_publishes_a_partial_backup() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("saved.zip");
        let mut source = Memory {
            bytes: b"original".to_vec(),
            reads: 0,
            change: true,
        };
        assert!(
            write_snapshot(
                &mut source,
                "org.synthetic.game",
                &json!({"version":"2.1.0"}),
                &path,
                true
            )
            .await
            .is_err()
        );
        assert!(!path.exists());
        assert_eq!(std::fs::read_dir(root.path()).unwrap().count(), 0);
    }
}
