//! One protected Keychain item per account; no plaintext credential files.
use isideload::util::storage::SideloadingStorage;
use rootcause::prelude::*;
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
};
use zeroize::{Zeroize, Zeroizing};

pub const SERVICE: &str = "com.nalancer08.nxnative.sideload.vault.v1";
pub const LEGACY_SESSION: &str = "com.nalancer08.nxnative.sideload.session";
pub const LEGACY_IDENTITY: &str = "com.nalancer08.nxnative.sideload.identity";
pub const NEEDS_ACCESS: &str = "Saved account needs foreground Keychain access";

trait Backend: Send + Sync {
    fn read(&self, service: &str, account: &str) -> Result<Option<Vec<u8>>, Report>;
    fn write(&self, account: &str, value: &[u8]) -> Result<(), Report>;
    fn delete_legacy_session(&self, account: &str) -> Result<(), Report>;
}
struct Keychain;
impl Backend for Keychain {
    fn read(&self, service: &str, account: &str) -> Result<Option<Vec<u8>>, Report> {
        match keyring::Entry::new(service, account)?.get_secret() {
            Ok(value) => Ok(Some(value)),
            Err(keyring::Error::NoEntry) => Ok(None),
            Err(_) => bail!(NEEDS_ACCESS),
        }
    }
    fn write(&self, account: &str, value: &[u8]) -> Result<(), Report> {
        keyring::Entry::new(SERVICE, account)?
            .set_secret(value)
            .map_err(|_| report!(NEEDS_ACCESS))?;
        Ok(())
    }
    fn delete_legacy_session(&self, account: &str) -> Result<(), Report> {
        match keyring::Entry::new(LEGACY_SESSION, account)?.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(_) => bail!(NEEDS_ACCESS),
        }
    }
}
#[derive(Clone, Serialize, Deserialize)]
struct Data {
    schema: u8,
    account: String,
    session: Option<Vec<u8>>,
    values: BTreeMap<String, String>,
}
impl Drop for Data {
    fn drop(&mut self) {
        if let Some(value) = &mut self.session {
            value.zeroize();
        }
        for value in self.values.values_mut() {
            value.zeroize();
        }
    }
}
struct Inner {
    backend: Arc<dyn Backend>,
    data: Mutex<Data>,
}
#[derive(Clone)]
pub struct Vault(Arc<Inner>);
impl Vault {
    pub fn open(account: &str, interactive: bool) -> Result<Self, Report> {
        Self::load(account, interactive, Arc::new(Keychain))
    }
    fn load(account: &str, interactive: bool, backend: Arc<dyn Backend>) -> Result<Self, Report> {
        let data = if let Some(bytes) = backend.read(SERVICE, account)? {
            let bytes = Zeroizing::new(bytes);
            if bytes.len() > 2 * 1024 * 1024 {
                bail!("Invalid account vault size")
            }
            let value: Data =
                serde_json::from_slice(&bytes).map_err(|_| report!("Invalid account vault"))?;
            if value.schema != 1 || value.account != account {
                bail!("Invalid account vault identity")
            }
            value
        } else {
            // Startup/background work must not prompt for the separate legacy records.
            if !interactive {
                bail!(NEEDS_ACCESS)
            }
            let mut value = Data {
                schema: 1,
                account: account.into(),
                session: backend.read(LEGACY_SESSION, account)?,
                values: BTreeMap::new(),
            };
            for key in ["anisette_state".to_owned(), format!("{account}/key")] {
                if let Some(bytes) = backend.read(LEGACY_IDENTITY, &key)? {
                    let bytes = Zeroizing::new(bytes);
                    let text = std::str::from_utf8(&bytes)
                        .map(str::to_owned)
                        .map_err(|_| report!("Invalid legacy identity encoding"))?;
                    value.values.insert(key, text);
                }
            }
            // Only publish after every legacy read succeeds. Never remove old identities.
            let bytes = Zeroizing::new(serde_json::to_vec(&value)?);
            backend.write(account, &bytes)?;
            value
        };
        Ok(Self(Arc::new(Inner {
            backend,
            data: Mutex::new(data),
        })))
    }
    fn change(&self, edit: impl FnOnce(&mut Data)) -> Result<(), Report> {
        let mut current = self
            .0
            .data
            .lock()
            .map_err(|_| report!("Account vault unavailable"))?;
        let mut next = current.clone();
        edit(&mut next);
        let bytes = Zeroizing::new(serde_json::to_vec(&next)?);
        self.0.backend.write(&next.account, &bytes)?;
        *current = next;
        Ok(())
    }
    pub fn session(&self) -> Result<Zeroizing<Vec<u8>>, Report> {
        self.0
            .data
            .lock()
            .map_err(|_| report!("Account vault unavailable"))?
            .session
            .clone()
            .map(Zeroizing::new)
            .ok_or_else(|| report!("No remembered session"))
    }
    pub fn remember(&self, value: &[u8]) -> Result<(), Report> {
        self.change(|data| {
            if let Some(mut old) = data.session.take() {
                old.zeroize();
            }
            data.session = Some(value.to_vec());
        })
    }
    pub fn forget(&self) -> Result<(), Report> {
        // Logout cannot resurrect a retained legacy token on a subsequent migration.
        let account = self
            .0
            .data
            .lock()
            .map_err(|_| report!("Account vault unavailable"))?
            .account
            .clone();
        self.0.backend.delete_legacy_session(&account)?;
        self.change(|data| {
            if let Some(mut old) = data.session.take() {
                old.zeroize();
            }
        })
    }
}
impl SideloadingStorage for Vault {
    fn store(&self, key: &str, value: &str) -> Result<(), Report> {
        self.change(|data| {
            if let Some(mut old) = data.values.insert(key.into(), value.into()) {
                old.zeroize();
            }
        })
    }
    fn retrieve(&self, key: &str) -> Result<Option<String>, Report> {
        Ok(self
            .0
            .data
            .lock()
            .map_err(|_| report!("Account vault unavailable"))?
            .values
            .get(key)
            .cloned())
    }
    fn delete(&self, key: &str) -> Result<(), Report> {
        self.change(|data| {
            if let Some(mut old) = data.values.remove(key) {
                old.zeroize();
            }
        })
    }
}

// keyring's macOS backend uses legacy SecKeychain APIs. This flag is process-local;
// our single-command helper suppresses prompts for the whole automatic operation,
// including writes, and restores the prior flag on every success/error path.
// It never grants access, unlocks the keychain, or changes an item's ACL.
pub struct QuietKeychain {
    previous: u8,
}
#[link(name = "Security", kind = "framework")]
unsafe extern "C" {
    fn SecKeychainGetUserInteractionAllowed(state: *mut u8) -> i32;
    fn SecKeychainSetUserInteractionAllowed(state: u8) -> i32;
}
impl QuietKeychain {
    pub fn begin() -> Result<Self, Report> {
        let mut previous = 0;
        unsafe {
            if SecKeychainGetUserInteractionAllowed(&mut previous) != 0 {
                bail!(NEEDS_ACCESS)
            }
            if SecKeychainSetUserInteractionAllowed(0) != 0 {
                SecKeychainSetUserInteractionAllowed(previous);
                bail!(NEEDS_ACCESS)
            }
        }
        Ok(Self { previous })
    }
}
impl Drop for QuietKeychain {
    fn drop(&mut self) {
        unsafe {
            SecKeychainSetUserInteractionAllowed(self.previous);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[derive(Default)]
    struct Fake {
        items: Mutex<BTreeMap<(String, String), Vec<u8>>>,
        reads: Mutex<Vec<(String, String)>>,
        fail_write: Mutex<bool>,
        deny_legacy: Mutex<bool>,
    }
    impl Backend for Fake {
        fn read(&self, s: &str, a: &str) -> Result<Option<Vec<u8>>, Report> {
            self.reads.lock().unwrap().push((s.into(), a.into()));
            if s != SERVICE && *self.deny_legacy.lock().unwrap() {
                bail!(NEEDS_ACCESS)
            }
            Ok(self
                .items
                .lock()
                .unwrap()
                .get(&(s.into(), a.into()))
                .cloned())
        }
        fn write(&self, a: &str, v: &[u8]) -> Result<(), Report> {
            if *self.fail_write.lock().unwrap() {
                bail!("Synthetic write failure")
            }
            self.items
                .lock()
                .unwrap()
                .insert((SERVICE.into(), a.into()), v.to_vec());
            Ok(())
        }
        fn delete_legacy_session(&self, a: &str) -> Result<(), Report> {
            self.items
                .lock()
                .unwrap()
                .remove(&(LEGACY_SESSION.into(), a.into()));
            Ok(())
        }
    }
    #[test]
    fn quiet_guard_restores_process_policy_including_nested_scopes() {
        let mut original = 0;
        assert_eq!(
            unsafe { SecKeychainGetUserInteractionAllowed(&mut original) },
            0
        );
        {
            let _outer = QuietKeychain::begin().unwrap();
            let mut current = 1;
            assert_eq!(
                unsafe { SecKeychainGetUserInteractionAllowed(&mut current) },
                0
            );
            assert_eq!(current, 0);
            {
                let _inner = QuietKeychain::begin().unwrap();
            }
            assert_eq!(
                unsafe { SecKeychainGetUserInteractionAllowed(&mut current) },
                0
            );
            assert_eq!(current, 0);
        }
        let mut restored = 0;
        assert_eq!(
            unsafe { SecKeychainGetUserInteractionAllowed(&mut restored) },
            0
        );
        assert_eq!(restored, original);
    }
    #[test]
    fn automatic_missing_vault_does_not_touch_legacy() {
        let b = Arc::new(Fake::default());
        assert!(Vault::load("a", false, b.clone()).is_err());
        assert_eq!(b.reads.lock().unwrap().as_slice(), &[(
            SERVICE.into(),
            "a".into()
        )]);
        assert!(b.items.lock().unwrap().is_empty());
    }
    #[test]
    fn migration_preserves_session_identity_and_old_items_then_reads_once() {
        let b = Arc::new(Fake::default());
        for (s, k, v) in [
            (LEGACY_SESSION, "a", b"session".as_slice()),
            (LEGACY_IDENTITY, "a/key", b"private-key"),
            (LEGACY_IDENTITY, "anisette_state", b"state"),
        ] {
            b.items
                .lock()
                .unwrap()
                .insert((s.into(), k.into()), v.to_vec());
        }
        let v = Vault::load("a", true, b.clone()).unwrap();
        assert_eq!(&**v.session().unwrap(), b"session");
        assert_eq!(v.retrieve("a/key").unwrap().as_deref(), Some("private-key"));
        assert_eq!(b.items.lock().unwrap().len(), 4);
        b.reads.lock().unwrap().clear();
        let v = Vault::load("a", false, b.clone()).unwrap();
        for _ in 0..5 {
            assert!(v.clone().retrieve("anisette_state").unwrap().is_some());
            assert!(v.session().is_ok());
        }
        assert_eq!(b.reads.lock().unwrap().len(), 1);
    }
    #[test]
    fn denied_migration_never_publishes_or_erases() {
        let b = Arc::new(Fake::default());
        *b.deny_legacy.lock().unwrap() = true;
        b.items
            .lock()
            .unwrap()
            .insert((LEGACY_SESSION.into(), "a".into()), b"original".to_vec());
        assert!(Vault::load("a", true, b.clone()).is_err());
        assert_eq!(b.items.lock().unwrap().len(), 1);
    }
    #[test]
    fn failed_write_preserves_cached_and_persisted_values() {
        let b = Arc::new(Fake::default());
        let v = Vault::load("a", true, b.clone()).unwrap();
        v.remember(b"old").unwrap();
        *b.fail_write.lock().unwrap() = true;
        assert!(v.remember(b"new").is_err());
        assert_eq!(&**v.session().unwrap(), b"old");
        *b.fail_write.lock().unwrap() = false;
        assert_eq!(
            &**Vault::load("a", false, b).unwrap().session().unwrap(),
            b"old"
        );
    }
    #[test]
    fn logout_retains_identity_but_removes_both_session_copies() {
        let b = Arc::new(Fake::default());
        b.items
            .lock()
            .unwrap()
            .insert((LEGACY_SESSION.into(), "a".into()), b"old".to_vec());
        let v = Vault::load("a", true, b.clone()).unwrap();
        v.store("a/key", "same-key").unwrap();
        v.forget().unwrap();
        assert!(v.session().is_err());
        assert_eq!(v.retrieve("a/key").unwrap().as_deref(), Some("same-key"));
        assert!(b.read(LEGACY_SESSION, "a").unwrap().is_none());
    }
    #[test]
    fn malformed_or_wrong_account_vault_is_preserved() {
        let b = Arc::new(Fake::default());
        b.write("a", b"invalid").unwrap();
        assert!(Vault::load("a", true, b.clone()).is_err());
        assert_eq!(b.read(SERVICE, "a").unwrap().unwrap(), b"invalid");
        let v = Data {
            schema: 1,
            account: "b".into(),
            session: None,
            values: BTreeMap::new(),
        };
        b.write("a", &serde_json::to_vec(&v).unwrap()).unwrap();
        assert!(Vault::load("a", true, b).is_err());
    }
}
