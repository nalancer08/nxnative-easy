//! A scheduled reinstall must not silently interrupt a running game.
use rootcause::prelude::*;
use serde_json::Value;

fn executable_path(value: &Value) -> Option<&str> {
    value
        .as_str()
        .or_else(|| value.get("url").and_then(Value::as_str))
        .or_else(|| value.get("path").and_then(Value::as_str))
}
pub fn idle_from_json(value: &Value, executable: &str) -> Result<bool, Report> {
    let processes = value
        .get("result")
        .and_then(|v| v.get("runningProcesses"))
        .and_then(Value::as_array)
        .filter(|rows| !rows.is_empty())
        .ok_or_else(|| report!("Cannot verify game process state"))?;
    for process in processes {
        if let Some(path) = process.get("executable").and_then(executable_path) {
            let path = url::Url::parse(path)
                .ok()
                .and_then(|url| url.to_file_path().ok())
                .unwrap_or_else(|| std::path::PathBuf::from(path));
            if path.file_name().is_some_and(|name| name == executable) {
                return Ok(false);
            }
        } else if process
            .get("processIdentifier")
            .and_then(Value::as_u64)
            .is_none_or(|pid| pid > 1)
        {
            bail!("Cannot verify game process state")
        }
    }
    Ok(true)
}
pub fn require_idle(udid: &str, executable: &str) -> Result<(), Report> {
    let output = std::process::Command::new("/usr/bin/xcrun")
        .args([
            "devicectl",
            "device",
            "info",
            "processes",
            "--device",
            udid,
            "--timeout",
            "15",
            "--json-output",
            "-",
        ])
        .output()
        .map_err(|_| report!("Cannot verify game process state"))?;
    if !output.status.success() || output.stdout.len() > 8 * 1024 * 1024 {
        bail!("Cannot verify game process state")
    }
    let value: Value = serde_json::from_slice(&output.stdout)
        .map_err(|_| report!("Cannot verify game process state"))?;
    if !idle_from_json(&value, executable)? {
        bail!("Game is running; refresh postponed")
    };
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn running_and_unknown_states_do_not_allow_refresh() {
        let running = json!({"result":{"runningProcesses":[{"processIdentifier":40,"executable":"file:///private/var/Game.app/DmIOS"}]}});
        assert!(!idle_from_json(&running, "DmIOS").unwrap());
        let idle = json!({"result":{"runningProcesses":[{"processIdentifier":1,"executable":"file:///sbin/launchd"}]}});
        assert!(idle_from_json(&idle, "DmIOS").unwrap());
        for unknown in [
            json!({}),
            json!({"result":{"runningProcesses":[]}}),
            json!({"result":{"runningProcesses":[{"processIdentifier":40}]}}),
        ] {
            assert!(idle_from_json(&unknown, "DmIOS").is_err());
        }
    }
}
