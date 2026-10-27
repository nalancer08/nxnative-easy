//! Scope device discovery to locally prepared games and our exact installation records.
use idevice::IdeviceService;
use plist::{Dictionary, Value as Plist};
use rootcause::prelude::*;
use serde::Deserialize;
use serde_json::{Value, json};

#[derive(Clone, Default, Deserialize)]
pub struct Scope {
    #[serde(default)]
    pub original_ids: Vec<String>,
    #[serde(default)]
    pub known_ids: Vec<String>,
}
fn valid_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 255
        && id
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || c == b'.' || c == b'-')
}
fn standard_base(id: &str) -> bool {
    id.to_ascii_lowercase()
        .strip_prefix("org.nxnative.")
        .is_some_and(|title| title.len() == 16 && title.bytes().all(|c| c.is_ascii_hexdigit()))
}
impl Scope {
    pub fn validate(&self) -> Result<(), Report> {
        if self.original_ids.len() + self.known_ids.len() > 512
            || !self
                .original_ids
                .iter()
                .chain(&self.known_ids)
                .all(|id| valid_id(id))
        {
            bail!("Invalid game discovery scope")
        }
        Ok(())
    }
    pub fn permits(&self, id: &str) -> bool {
        valid_id(id)
            && (self.known_ids.iter().any(|known| known == id)
                || self.original_ids.iter().any(|base| {
                    base == id
                        || (standard_base(base)
                            && id
                                .to_ascii_lowercase()
                                .strip_prefix(&(base.to_ascii_lowercase() + "."))
                                .is_some_and(|suffix| {
                                    suffix.len() == 10
                                        && suffix.bytes().all(|c| c.is_ascii_alphanumeric())
                                }))
                }))
    }
    fn exact(&self) -> Vec<String> {
        self.original_ids
            .iter()
            .chain(&self.known_ids)
            .cloned()
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect()
    }
}
async fn lookup(
    client: &mut idevice::installation_proxy::InstallationProxyClient,
    scope: &Scope,
    ids: Vec<String>,
) -> Result<Vec<Value>, Report> {
    // An empty BundleIDs array must never become an unrestricted Lookup.
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    let requested: std::collections::BTreeSet<_> = ids.iter().cloned().collect();
    let apps = client.get_apps(Some("User"), Some(ids)).await?;
    // Never expose a response from a service ignoring the explicit bundle scope.
    if apps
        .keys()
        .any(|id| !requested.contains(id) || !scope.permits(id))
    {
        bail!("Game discovery scope was ignored")
    }
    Ok(apps.into_iter().filter_map(|(id,app)|{
        let app=app.as_dictionary()?;
        let name=app.get("CFBundleDisplayName").or_else(||app.get("CFBundleName")).and_then(Plist::as_string).unwrap_or(&id);
        Some(json!({"id":id,"name":name,"executable":app.get("CFBundleExecutable").and_then(Plist::as_string).unwrap_or(""),"version":app.get("CFBundleShortVersionString").and_then(Plist::as_string).unwrap_or("")}))
    }).collect())
}
pub async fn installed(udid: &str, scope: &Scope) -> Result<Vec<Value>, Report> {
    scope.validate()?;
    let ids = scope.exact();
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    let provider = super::provider(udid).await?;
    let mut client =
        idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?;
    let mut result = lookup(&mut client, scope, ids).await?;
    // Existing exact installations need no device-wide identifier discovery.
    let missing = scope
        .original_ids
        .iter()
        .filter(|base| {
            standard_base(base)
                && !result.iter().any(|item| {
                    item["id"].as_str().is_some_and(|id| {
                        id.eq_ignore_ascii_case(base)
                            || id
                                .to_ascii_lowercase()
                                .starts_with(&(base.to_ascii_lowercase() + "."))
                    })
                })
        })
        .cloned()
        .collect::<Vec<_>>();
    if !missing.is_empty() {
        let mut options = Dictionary::new();
        options.insert("ApplicationType".into(), Plist::String("User".into()));
        options.insert(
            "ReturnAttributes".into(),
            Plist::Array(vec![Plist::String("CFBundleIdentifier".into())]),
        );
        // Legacy suffix discovery reads identifiers only; no names, paths or containers.
        let index = client.browse(Some(Plist::Dictionary(options))).await?;
        let legacy = Scope {
            original_ids: missing,
            known_ids: vec![],
        };
        let mut matches = std::collections::BTreeSet::new();
        for entry in index {
            let entry = entry
                .as_dictionary()
                .ok_or_else(|| report!("Cannot query scoped games"))?;
            if entry.keys().any(|key| key != "CFBundleIdentifier") {
                bail!("Game discovery scope was ignored")
            }
            if let Some(id) = entry
                .get("CFBundleIdentifier")
                .and_then(Plist::as_string)
                .filter(|id| legacy.permits(id))
            {
                matches.insert(id.to_string());
            }
        }
        result.extend(lookup(&mut client, scope, matches.into_iter().collect()).await?);
    }
    Ok(result)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn only_exact_records_or_known_title_with_single_team_suffix_match() {
        let scope = Scope {
            original_ids: vec![
                "org.nxnative.010093801237c000".into(),
                "org.custom.game".into(),
            ],
            known_ids: vec!["org.old.custom.GAME".into()],
        };
        for id in [
            "org.nxnative.010093801237c000",
            "org.nxnative.010093801237c000.ABCDE12345",
            "org.custom.game",
            "org.old.custom.GAME",
        ] {
            assert!(scope.permits(id), "{id}")
        }
        for id in [
            "com.apple.mail",
            "com.bank.metroid",
            "org.nxnative.010093801237c000evil",
            "org.nxnative.010093801237c000.news",
            "org.nxnative.010093801237c000.ABCDE12345.extra",
            "org.nxnative.01007ef00011e000.ABCDE12345",
            "org.custom.game.ABCDE12345",
        ] {
            assert!(!scope.permits(id), "{id}")
        }
        assert!(!Scope::default().permits("org.nxnative.010093801237c000"));
    }
    #[tokio::test]
    async fn no_scope_never_opens_a_device_connection() {
        assert!(
            installed("NOT-A-REAL-DEVICE", &Scope::default())
                .await
                .unwrap()
                .is_empty()
        );
    }
    #[test]
    fn invalid_or_unbounded_scopes_are_refused() {
        assert!(
            Scope {
                original_ids: vec!["*".into()],
                known_ids: vec![]
            }
            .validate()
            .is_err()
        );
        assert!(
            Scope {
                original_ids: vec!["org.game".into(); 513],
                known_ids: vec![]
            }
            .validate()
            .is_err()
        );
    }
}
