use std::env;
use std::fs;
use std::io;
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};

pub const STATE_DIR_ENV: &str = "THUMBLE_HOST_STATE_DIR";
pub const CONTROL_SOCKET_ENV: &str = "THUMBLE_HOST_CONTROL_SOCKET";
const LEGACY_STATE_DIR_ENV: &str = "POCKETPAD_HOST_STATE_DIR";
const LEGACY_CONTROL_SOCKET_ENV: &str = "POCKETPAD_HOST_CONTROL_SOCKET";
const STATE_DIRECTORY_NAME: &str = "ThumbleHost";
const LEGACY_STATE_DIRECTORY_NAME: &str = "PocketPadHost";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostPaths {
    pub state_dir: PathBuf,
    pub state_file: PathBuf,
    pub lock_file: PathBuf,
    pub pid_file: PathBuf,
    pub runtime_file: PathBuf,
    pub log_file: PathBuf,
    pub output_recording_file: PathBuf,
    pub drafts_dir: PathBuf,
    pub artifacts_dir: PathBuf,
    pub control_socket: PathBuf,
}

impl HostPaths {
    pub fn discover() -> io::Result<Self> {
        let state_dir = match configured_path(STATE_DIR_ENV, LEGACY_STATE_DIR_ENV) {
            Some(path) => path,
            None => default_state_dir()?,
        };
        let control_socket = configured_path(CONTROL_SOCKET_ENV, LEGACY_CONTROL_SOCKET_ENV)
            .unwrap_or_else(|| state_dir.join("control.sock"));
        Ok(Self::new(state_dir, control_socket))
    }

    pub fn new(state_dir: PathBuf, control_socket: PathBuf) -> Self {
        Self {
            state_file: state_dir.join("state.json"),
            lock_file: state_dir.join("runtime.lock"),
            pid_file: state_dir.join("runtime.pid"),
            runtime_file: state_dir.join("runtime.json"),
            log_file: state_dir.join("host.log"),
            output_recording_file: state_dir.join("recorded-output.jsonl"),
            drafts_dir: state_dir.join("drafts"),
            artifacts_dir: state_dir.join("artifacts/sha256"),
            state_dir,
            control_socket,
        }
    }

    pub fn ensure_state_dir(&self) -> io::Result<()> {
        if let Ok(metadata) = fs::symlink_metadata(&self.state_dir) {
            if metadata.file_type().is_symlink() || !metadata.is_dir() {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    "host state directory must be a real directory",
                ));
            }
            if metadata.uid() != unsafe { libc::geteuid() } {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    "host state directory must be owned by the current user",
                ));
            }
        }
        fs::create_dir_all(&self.state_dir)?;
        fs::set_permissions(&self.state_dir, fs::Permissions::from_mode(0o700))?;
        let metadata = fs::symlink_metadata(&self.state_dir)?;
        if metadata.file_type().is_symlink()
            || !metadata.is_dir()
            || metadata.uid() != unsafe { libc::geteuid() }
            || metadata.permissions().mode() & 0o077 != 0
        {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "host state directory failed ownership or permission checks",
            ));
        }
        Ok(())
    }
}

fn default_state_dir() -> io::Result<PathBuf> {
    let home = env::var_os("HOME")
        .filter(|home| !home.is_empty())
        .map(PathBuf::from)
        .or_else(home_from_passwd)
        .ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::NotFound,
                "could not determine home directory",
            )
        })?;
    Ok(default_state_dir_for_home(&home))
}

fn configured_path(canonical: &str, legacy: &str) -> Option<PathBuf> {
    env::var_os(canonical)
        .filter(|value| !value.is_empty())
        .or_else(|| env::var_os(legacy).filter(|value| !value.is_empty()))
        .map(PathBuf::from)
}

fn default_state_dir_for_home(home: &Path) -> PathBuf {
    let application_support = home.join("Library/Application Support");
    let canonical = application_support.join(STATE_DIRECTORY_NAME);
    let legacy = application_support.join(LEGACY_STATE_DIRECTORY_NAME);
    if !canonical.exists() && legacy.exists() {
        legacy
    } else {
        canonical
    }
}

fn home_from_passwd() -> Option<PathBuf> {
    // SAFETY: getpwuid returns process-global immutable storage. We copy the
    // home path before returning and check every nullable pointer.
    unsafe {
        let entry = libc::getpwuid(libc::geteuid());
        if entry.is_null() || (*entry).pw_dir.is_null() {
            return None;
        }
        let bytes = std::ffi::CStr::from_ptr((*entry).pw_dir).to_bytes();
        use std::os::unix::ffi::OsStrExt;
        Some(Path::new(std::ffi::OsStr::from_bytes(bytes)).to_path_buf())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn explicit_paths_keep_control_override_independent() {
        let paths = HostPaths::new(PathBuf::from("/state"), PathBuf::from("/socket/control"));
        assert_eq!(paths.state_file, PathBuf::from("/state/state.json"));
        assert_eq!(paths.control_socket, PathBuf::from("/socket/control"));
        assert_eq!(paths.log_file, PathBuf::from("/state/host.log"));
        assert_eq!(paths.drafts_dir, PathBuf::from("/state/drafts"));
        assert_eq!(
            paths.artifacts_dir,
            PathBuf::from("/state/artifacts/sha256")
        );
    }

    #[test]
    fn canonical_state_directory_is_preferred_with_legacy_fallback() {
        let home = tempfile::tempdir().unwrap();
        let support = home.path().join("Library/Application Support");
        let canonical = support.join(STATE_DIRECTORY_NAME);
        let legacy = support.join(LEGACY_STATE_DIRECTORY_NAME);

        assert_eq!(default_state_dir_for_home(home.path()), canonical);
        fs::create_dir_all(&legacy).unwrap();
        assert_eq!(default_state_dir_for_home(home.path()), legacy);
        fs::create_dir_all(&canonical).unwrap();
        assert_eq!(default_state_dir_for_home(home.path()), canonical);
    }
}
