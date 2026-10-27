//! Private stdio protocol. Never print requests, passwords, session tokens or provider responses.
mod idle;
mod romfs;
use idevice::{
    IdeviceService,
    provider::UsbmuxdProvider,
    usbmuxd::{UsbmuxdAddr, UsbmuxdConnection},
};
use isideload::{
    anisette::remote_v3::RemoteV3AnisetteProvider,
    auth::apple_account::{AppleAccount, TwoFactorCallbackParams, TwoFactorCallbackResponse},
    dev::{developer_session::DeveloperSession, devices::DevicesApi, teams::DeveloperTeam},
    sideload::{SideloaderBuilder, builder::MaxCertsBehavior, sideloader::Sideloader},
    util::{
        callbacks::{ExtensionsBehaviorCallbackBox, MaxCertsCallbackBox},
        device::IdeviceInfo,
        keyring_storage::KeyringStorage,
    },
};
use rootcause::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    io::{self, BufRead, Read, Write},
    path::{Path, PathBuf},
    sync::{LazyLock, Mutex},
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use zeroize::Zeroize;

const SESSION_SERVICE: &str = "com.nalancer08.nxnative.sideload.session";
const IDENTITY_SERVICE: &str = "com.nalancer08.nxnative.sideload.identity";
static INPUT: LazyLock<Mutex<io::BufReader<io::Stdin>>> =
    LazyLock::new(|| Mutex::new(io::BufReader::new(io::stdin())));
type Loader = Sideloader<MaxCertsCallbackBox, ExtensionsBehaviorCallbackBox>;
struct Session {
    email: String,
    teams: Vec<DeveloperTeam>,
    loader: Loader,
}

fn emit(value: Value) {
    let mut output = io::stdout().lock();
    let _ = writeln!(output, "{value}");
    let _ = output.flush();
}
fn read_request() -> Result<Value, Report> {
    let mut input = INPUT.lock().map_err(|_| report!("Input unavailable"))?;
    let mut line = Vec::new();
    loop {
        let buffer = input.fill_buf()?;
        if buffer.is_empty() {
            bail!("Input closed")
        };
        let end = buffer
            .iter()
            .position(|b| *b == b'\n')
            .map_or(buffer.len(), |p| p + 1);
        line.extend_from_slice(&buffer[..end]);
        input.consume(end);
        if line.len() > 65536 {
            bail!("Request too large")
        };
        if line.last() == Some(&b'\n') {
            break;
        }
    }
    Ok(serde_json::from_slice(&line)?)
}
fn text<'a>(request: &'a Value, key: &str) -> Result<&'a str, Report> {
    request[key]
        .as_str()
        .filter(|s| !s.is_empty())
        .ok_or_else(|| report!("Missing field"))
}
fn session_key(email: &str) -> String {
    hex::encode(Sha256::digest(email.trim().to_lowercase().as_bytes()))
}
fn validate_anisette(value: &str) -> Result<(), Report> {
    let url = url::Url::parse(value)?;
    if url.scheme() != "https"
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
    {
        bail!("Use an HTTPS anisette endpoint")
    };
    Ok(())
}
fn effective_id(
    original: &str,
    team: &str,
    expected: Option<&str>,
) -> Result<(String, String), Report> {
    if !team.chars().all(|c| c.is_ascii_alphanumeric()) || team.len() != 10 {
        bail!("Invalid team")
    }
    let effective = expected
        .map(str::to_owned)
        .unwrap_or_else(|| format!("{original}.{team}"));
    if effective.len() > 255
        || !effective
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-')
    {
        bail!("Invalid identifier")
    }
    Ok((effective.clone(), effective))
}
async fn provider(udid: &str) -> Result<UsbmuxdProvider, Report> {
    let mut mux = UsbmuxdConnection::default().await?;
    let devices = mux.get_devices().await?;
    let device = devices
        .into_iter()
        .find(|d| d.udid == udid)
        .ok_or_else(|| report!("Device disconnected"))?;
    Ok(device.to_provider(UsbmuxdAddr::from_env_var()?, "nxnative-easy"))
}
async fn devices() -> Result<(), Report> {
    let mut mux = UsbmuxdConnection::default().await?;
    let mut result = Vec::new();
    for device in mux.get_devices().await? {
        let p = device.to_provider(UsbmuxdAddr::from_env_var()?, "nxnative-easy");
        let name = tokio::time::timeout(Duration::from_secs(3), IdeviceInfo::from_device(&p))
            .await
            .ok()
            .and_then(Result::ok)
            .map(|i| i.name)
            .unwrap_or_else(|| "iPhone / iPad — unlock and trust this Mac".into());
        result.push(json!({"udid":device.udid,"name":name}));
    }
    emit(json!({"event":"devices","items":result}));
    Ok(())
}
async fn installed(udid: &str) -> Result<Vec<Value>, Report> {
    let p = provider(udid).await?;
    let mut client = idevice::installation_proxy::InstallationProxyClient::connect(&p).await?;
    let apps = client.get_apps(Some("User"), None).await?;
    let result = apps
        .into_iter()
        .filter_map(|(id, app)| {
            let app = app.as_dictionary()?;
            let name = app
                .get("CFBundleDisplayName")
                .or_else(|| app.get("CFBundleName"))
                .and_then(plist::Value::as_string)
                .unwrap_or(&id);
            Some(json!({"id":id,"name":name}))
        })
        .collect();
    Ok(result)
}
async fn login(request: &mut Value, restore: bool) -> Result<Session, Report> {
    let email = text(request, "email")?.trim().to_lowercase();
    let endpoint = text(request, "anisette_url")?.to_string();
    validate_anisette(&endpoint)?;
    let anisette = RemoteV3AnisetteProvider::default()?
        .set_url(&endpoint)
        .set_storage(Box::new(KeyringStorage::new(IDENTITY_SERVICE.into())));
    let mut account = AppleAccount::builder(&email)
        .anisette_provider(anisette)
        .err_429_retries(Some(1))
        .build()
        .await?;
    let entry = keyring::Entry::new(SESSION_SERVICE, &session_key(&email))?;
    if restore {
        account.spd = Some(plist::from_bytes(&entry.get_secret()?)?)
    } else {
        let mut password = text(request, "password")?.to_string();
        request["password"] = Value::Null;
        let callback =
            async |params: TwoFactorCallbackParams| -> Result<TwoFactorCallbackResponse, Report> {
                let numbers: Vec<_> = params
                    .numbers
                    .iter()
                    .map(|number| json!({"id":number.id,"last_digits":number.last_two_digits}))
                    .collect();
                emit(
                    json!({"event":"two_factor","sms":params.sms,"unknown":params.unknown,"numbers":numbers}),
                );
                let reply = tokio::task::spawn_blocking(read_request).await??;
                Ok(match reply["op"].as_str() {
                    Some("code") => {
                        TwoFactorCallbackResponse::SubmitCode(text(&reply, "code")?.to_string())
                    }
                    Some("sms") => TwoFactorCallbackResponse::SendSms(
                        reply["number"]
                            .as_u64()
                            .filter(|id| *id <= u32::MAX as u64)
                            .ok_or_else(|| report!("Invalid trusted number"))?
                            as u32,
                    ),
                    Some("resend") => TwoFactorCallbackResponse::ResendCode,
                    Some("send_to_devices") => TwoFactorCallbackResponse::SendToDevices,
                    _ => TwoFactorCallbackResponse::Abort,
                })
            };
        let result = account.login(&password, callback).await;
        password.zeroize();
        result?;
    }
    let developer = DeveloperSession::from_account(&mut account).await?;
    if !restore && request["remember"].as_bool() == Some(true) {
        let mut bytes = Vec::new();
        plist::to_writer_binary(&mut bytes, &account.spd)?;
        entry.set_secret(&bytes)?;
        bytes.zeroize();
    }
    use isideload::dev::teams::TeamsApi;
    let mut developer = developer;
    let teams = developer.list_teams().await?;
    let callback: MaxCertsCallbackBox = Box::new(|_| Box::pin(async { Ok(None) }));
    let loader = SideloaderBuilder::<MaxCertsCallbackBox, ExtensionsBehaviorCallbackBox>::new(
        developer,
        email.clone(),
    )
    .storage(Box::new(KeyringStorage::new(IDENTITY_SERVICE.into())))
    .machine_name("nxnative Easy".into())
    .max_certs_behavior(MaxCertsBehavior::Prompt(callback))
    .build();
    let choices: Vec<_> = teams
        .iter()
        .map(|t| json!({"id":t.team_id,"name":t.name}))
        .collect();
    emit(json!({"event":"signed_in","teams":choices}));
    Ok(Session {
        email,
        teams,
        loader,
    })
}
fn rebind_app(app: &Path, original: &str, effective: &str) -> Result<(), Report> {
    let mut prepared = isideload::sideload::application::Application::new(app.to_path_buf())?;
    prepared.update_bundle_id(original, effective)?;
    prepared.bundle.write_info()?;
    for extension in prepared.bundle.app_extensions() {
        extension.write_info()?;
    }
    Ok(())
}
fn hash_file(path: &Path) -> Result<String, Report> {
    let mut input = std::fs::File::open(path)?;
    let mut digest = Sha256::new();
    let mut chunk = [0u8; 65536];
    loop {
        let n = input.read(&mut chunk)?;
        if n == 0 {
            break;
        };
        digest.update(&chunk[..n]);
    }
    Ok(hex::encode(digest.finalize()))
}
fn extract(ipa: &Path, stage: &Path) -> Result<PathBuf, Report> {
    let file = std::fs::File::open(ipa)?;
    let mut zip = zip::ZipArchive::new(file)?;
    if zip.len() > 200000 {
        bail!("Too many IPA entries")
    }
    let mut expanded = 0u64;
    for index in 0..zip.len() {
        let mut entry = zip.by_index(index)?;
        let relative = entry
            .enclosed_name()
            .ok_or_else(|| report!("Unsafe archive path"))?;
        if entry.is_symlink() || entry.encrypted() || relative.to_string_lossy().contains('\\') {
            bail!("Unsafe IPA entry")
        }
        if relative
            .file_name()
            .is_some_and(|n| n == "prod.keys" || n == "title.keys")
        {
            bail!("Credentials are not IPA resources")
        }
        expanded = expanded
            .checked_add(entry.size())
            .ok_or_else(|| report!("IPA too large"))?;
        if expanded > 16 * 1024 * 1024 * 1024 {
            bail!("IPA too large")
        }
        let output = stage.join(relative);
        if entry.is_dir() {
            std::fs::create_dir_all(output)?
        } else {
            if let Some(parent) = output.parent() {
                std::fs::create_dir_all(parent)?
            };
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&output)?;
            io::copy(&mut entry, &mut file)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                std::fs::set_permissions(
                    &output,
                    std::fs::Permissions::from_mode(
                        if entry.unix_mode().unwrap_or(0) & 0o111 != 0 {
                            0o755
                        } else {
                            0o644
                        },
                    ),
                )?;
            }
        }
    }
    let apps: Vec<_> = std::fs::read_dir(stage.join("Payload"))?
        .filter_map(Result::ok)
        .map(|p| p.path())
        .filter(|p| p.is_dir() && p.extension().is_some_and(|v| v == "app"))
        .collect();
    if apps.len() != 1 {
        bail!("Expected one application")
    };
    Ok(apps[0].clone())
}
fn profile_details(app: &Path, effective: &str, team: &str) -> Result<u64, Report> {
    let output = std::process::Command::new("/usr/bin/security")
        .args(["cms", "-D", "-i"])
        .arg(app.join("embedded.mobileprovision"))
        .output()?;
    if !output.status.success() {
        bail!("Cannot verify provisioning profile")
    }
    let value: plist::Dictionary = plist::from_bytes(&output.stdout)?;
    let identifier = value
        .get("Entitlements")
        .and_then(plist::Value::as_dictionary)
        .and_then(|e| e.get("application-identifier"))
        .and_then(plist::Value::as_string);
    if identifier != Some(format!("{team}.{effective}").as_str()) {
        bail!("Provisioned identity mismatch")
    }
    let date = value
        .get("ExpirationDate")
        .and_then(plist::Value::as_date)
        .ok_or_else(|| report!("Missing profile expiry"))?;
    let expiry: SystemTime = date.into();
    let timestamp = expiry.duration_since(UNIX_EPOCH)?.as_secs();
    if expiry <= SystemTime::now() {
        bail!("Expired provisioning profile")
    };
    Ok(timestamp)
}
async fn install(session: &mut Session, request: &Value) -> Result<(), Report> {
    let ipa = PathBuf::from(text(request, "ipa")?);
    if !ipa.is_file() || ipa.extension().is_none_or(|v| v != "ipa") {
        bail!("Choose an IPA")
    }
    let team_id = text(request, "team")?;
    let team = session
        .teams
        .iter()
        .find(|t| t.team_id == team_id)
        .cloned()
        .ok_or_else(|| report!("Select your personal developer team"))?;
    let udid = text(request, "udid")?;
    let p = provider(udid).await?;
    let info = IdeviceInfo::from_device(&p).await?;
    let expected = request["expected_id"].as_str().filter(|s| !s.is_empty());
    let original = text(request, "original_id")?;
    let (base, effective) = effective_id(original, team_id, expected)?;
    let source_sha = hash_file(&ipa)?;
    if request["sha256"]
        .as_str()
        .is_some_and(|old| old != source_sha)
    {
        bail!("Prepared IPA changed; prepare and approve an update")
    };
    let apps = installed(udid).await?;
    if request["update"].as_bool() == Some(true)
        && !apps.iter().any(|a| a["id"].as_str() == Some(&effective))
    {
        bail!("Existing app identity was not found; installation stopped")
    }
    if expected.is_none()
        && apps.iter().any(|a| {
            a["id"]
                .as_str()
                .is_some_and(|id| id.starts_with(original) && id != effective)
        })
    {
        bail!("Another installation identity exists; select it before updating")
    }
    let work = PathBuf::from(text(request, "work")?);
    std::fs::create_dir_all(&work)?;
    let temp = tempfile::Builder::new()
        .prefix("install-")
        .tempdir_in(work)?;
    emit(json!({"event":"progress","phase":"Preparing IPA","fraction":0.0}));
    let app = extract(&ipa, temp.path())?;
    if hash_file(&ipa)? != source_sha {
        bail!("Prepared IPA changed during extraction")
    }
    let metadata: plist::Dictionary = plist::from_file(app.join("Info.plist"))?;
    if metadata
        .get("CFBundleIdentifier")
        .and_then(plist::Value::as_string)
        != Some(original)
    {
        bail!("IPA identity changed; prepare it again")
    }
    let executable = metadata
        .get("CFBundleExecutable")
        .and_then(plist::Value::as_string)
        .ok_or_else(|| report!("Missing game executable"))?
        .to_string();
    let automatic = request["automatic"].as_bool() == Some(true);
    if automatic {
        idle::require_idle(udid, &executable)?;
    }
    // Rebind the main bundle and its extensions using the SDK's own prefix rules.
    rebind_app(&app, original, &base)?;
    if request["update"].as_bool() == Some(true) {
        let name = metadata
            .get("CFBundleDisplayName")
            .or_else(|| metadata.get("CFBundleName"))
            .and_then(plist::Value::as_string);
        let matches = apps
            .iter()
            .find(|a| a["id"].as_str() == Some(effective.as_str()))
            .is_some_and(|a| {
                a["id"].as_str().is_some_and(|id| id.starts_with(original))
                    || a["name"].as_str() == name
            });
        if !matches {
            bail!("Selected installed app does not match this game")
        }
    }
    session
        .loader
        .get_dev_session()
        .ensure_device_registered(&team, &info.name, &info.udid, None)
        .await?;
    let progress = |fraction: f32| async move {
        emit(json!({"event":"progress","phase":"Signing app","fraction":fraction}));
    };
    let (signed, _) = session
        .loader
        .sign_app(app, Some(team), true, Some(progress), None, Some(udid))
        .await?;
    let signed_info: plist::Dictionary = plist::from_file(signed.join("Info.plist"))?;
    if signed_info
        .get("CFBundleIdentifier")
        .and_then(plist::Value::as_string)
        != Some(effective.as_str())
    {
        bail!("Signed identity mismatch; not installed")
    }
    let expires = profile_details(&signed, &effective, team_id)?;
    let verify = std::process::Command::new("/usr/bin/codesign")
        .args(["--verify", "--deep", "--strict"])
        .arg(&signed)
        .output()?;
    if !verify.status.success() {
        bail!("Signed application verification failed")
    }
    if automatic {
        idle::require_idle(udid, &executable)?;
    }
    isideload::sideload::install::install_app(&p, &signed, |fraction| {
        emit(json!({"event":"progress","phase":"Installing app","fraction":fraction as f64/100.0}))
    })
    .await?;
    if let Some(path) = request["romfs"].as_str().filter(|p| !p.is_empty()) {
        romfs::transfer(&p, &effective, Path::new(path)).await?;
    }
    emit(
        json!({"event":"installed","sha256":source_sha,"effective_id":effective,"expires":expires,"udid":udid,"email":session.email}),
    );
    Ok(())
}
#[tokio::main]
async fn main() {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let _ = isideload::init();
    emit(json!({"event":"hello","protocol":1,"architecture":std::env::consts::ARCH}));
    let mut session: Option<Session> = None;
    while let Ok(mut request) = read_request() {
        let op = request["op"].as_str().unwrap_or("").to_string();
        let result = match op.as_str() {
            "devices" => devices().await,
            "installed_apps" => match text(&request, "udid") {
                Ok(udid) => match installed(udid).await {
                    Ok(items) => {
                        emit(json!({"event":"installed_apps","items":items}));
                        Ok(())
                    }
                    Err(e) => Err(e),
                },
                Err(e) => Err(e),
            },
            "login" | "restore" => match login(&mut request, op == "restore").await {
                Ok(value) => {
                    session = Some(value);
                    Ok(())
                }
                Err(e) => {
                    session = None;
                    Err(e)
                }
            },
            "install" => match &mut session {
                Some(value) => install(value, &request).await,
                None => Err(report!("Sign in first")),
            },
            "logout" => {
                if let Ok(email) = text(&request, "email") {
                    if let Ok(entry) = keyring::Entry::new(SESSION_SERVICE, &session_key(email)) {
                        let _ = entry.delete_credential();
                    }
                };
                session = None;
                emit(json!({"event":"signed_out"}));
                Ok(())
            }
            "quit" => break,
            _ => Err(report!("Unknown operation")),
        };
        if let Err(error) = result {
            let apple_code = error.iter_reports().find_map(|node| {
                match node.downcast_current_context::<isideload::SideloadError>() {
                    Some(isideload::SideloadError::AuthWithMessage(code, _))
                    | Some(isideload::SideloadError::DeveloperError(code, _)) => Some(*code),
                    _ => None,
                }
            });
            let detail = error.to_string();
            let code = if detail.contains("Game is running") {
                "game_running"
            } else if detail.contains("Cannot verify game process") {
                "idle_unknown"
            } else if detail.contains("identifier cannot be preserved") {
                "identity_mismatch"
            } else if detail.contains("not found; installation stopped") {
                "not_installed"
            } else if detail.contains("does not match this game") {
                "wrong_app"
            } else if detail.contains("storage") {
                "storage"
            } else if detail.contains("IPA changed") {
                "ipa_changed"
            } else {
                "failed"
            };
            emit(
                json!({"event":"error","code":code,"apple_code":apple_code,"operation":op,"message":match op.as_str(){"login"|"restore"=>"Sign-in failed or the saved session expired. Sign in again; no password was logged.","install"=>"Install stopped. Check the selected device, team and existing app identifier. Certificates were not automatically revoked.",_=>"Operation failed. Unlock the device, trust this Mac and reconnect."}}),
            );
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn identifiers_preserve_update_identity() {
        assert_eq!(
            effective_id("org.game", "ABCDE12345", None).unwrap(),
            ("org.game.ABCDE12345".into(), "org.game.ABCDE12345".into())
        );
        assert_eq!(
            effective_id("org.new", "ABCDE12345", Some("org.old.ABCDE12345"))
                .unwrap()
                .1,
            "org.old.ABCDE12345"
        );
        assert_eq!(
            effective_id("org.game", "ABCDE12345", Some("org.game.custom"))
                .unwrap()
                .1,
            "org.game.custom"
        );
        assert!(effective_id("org.game", "wrong", None).is_err());
    }
    #[test]
    fn custom_identity_persists_to_main_and_extension() {
        let temp = tempfile::tempdir().unwrap();
        let app = temp.path().join("Game.app");
        let extension = app.join("PlugIns/Widget.appex");
        std::fs::create_dir_all(&extension).unwrap();
        for (path, id) in [(&app, "org.game"), (&extension, "org.game.widget")] {
            let mut info = plist::Dictionary::new();
            info.insert("CFBundleIdentifier".into(), plist::Value::String(id.into()));
            info.insert("CFBundleName".into(), plist::Value::String("Game".into()));
            plist::to_file_binary(path.join("Info.plist"), &info).unwrap();
        }
        rebind_app(&app, "org.game", "org.existing.custom").unwrap();
        let main: plist::Dictionary = plist::from_file(app.join("Info.plist")).unwrap();
        let widget: plist::Dictionary = plist::from_file(extension.join("Info.plist")).unwrap();
        assert_eq!(
            main["CFBundleIdentifier"].as_string(),
            Some("org.existing.custom")
        );
        assert_eq!(
            widget["CFBundleIdentifier"].as_string(),
            Some("org.existing.custom.widget")
        );
    }
    #[test]
    fn private_session_plist_roundtrips_without_passwords() {
        let mut value = plist::Dictionary::new();
        value.insert("adsid".into(), plist::Value::String("synthetic".into()));
        let mut bytes = Vec::new();
        plist::to_writer_binary(&mut bytes, &Some(value.clone())).unwrap();
        let recovered: plist::Dictionary = plist::from_bytes(&bytes).unwrap();
        assert_eq!(recovered, value);
    }
    #[test]
    fn zip_export_rejects_traversal_and_keeps_original_bytes() {
        use zip::write::SimpleFileOptions;
        let temp = tempfile::tempdir().unwrap();
        let archive = temp.path().join("test.ipa");
        let mut writer = zip::ZipWriter::new(std::fs::File::create(&archive).unwrap());
        writer
            .start_file("../save", SimpleFileOptions::default())
            .unwrap();
        writer.write_all(b"synthetic").unwrap();
        writer.finish().unwrap();
        let before = std::fs::read(&archive).unwrap();
        let destination = temp.path().join("stage");
        std::fs::create_dir(&destination).unwrap();
        assert!(extract(&archive, &destination).is_err());
        assert!(!temp.path().join("save").exists());
        assert_eq!(std::fs::read(&archive).unwrap(), before);
    }
    #[test]
    fn anisette_requires_authenticated_transport() {
        assert!(validate_anisette("https://ani.iloader.app").is_ok());
        assert!(validate_anisette("http://localhost").is_err());
        assert!(validate_anisette("https://user:secret@example.org").is_err());
    }
}
