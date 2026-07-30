use crate::bonjour::BonjourInfo;
use crate::cli_profile::{CliProfileRequest, CliProfileResponse};
use crate::draft_operation::{ConfigurationOperation, ConfigurationOperationOutcome};
use crate::output::OutputSnapshot;
use serde::{Deserialize, Serialize};
use std::fs;
use std::os::fd::AsRawFd;
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use thumble_core::{ControllerSnapshot, StatusSnapshot};
use thumble_protocol::KeypadElementInputPart;
use tokio::io::{AsyncBufRead, AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{watch, Semaphore};

const MAXIMUM_CONTROL_LINE: usize = 64 * 1024;
const MAXIMUM_CONTROL_CONNECTIONS: usize = 16;
const CONTROL_LINE_TIMEOUT: Duration = Duration::from_secs(5);
const CONTROL_WRITE_TIMEOUT: Duration = Duration::from_secs(5);
const CONTROL_ADMISSION_TIMEOUT: Duration = Duration::from_millis(500);
// Draft transforms can legitimately consume the bridge's full five-second
// deadline and still need bounded atomic draft persistence before replying.
// Keep the caller deadline longer so a successful revision-safe edit is not
// reported with an ambiguous client timeout.
const CONTROL_REQUEST_TIMEOUT: Duration = Duration::from_secs(15);

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "command", rename_all = "kebab-case")]
pub enum ControlRequest {
    Status,
    PairingCode {
        #[serde(default)]
        rotate: bool,
    },
    Accessibility {
        action: AccessibilityAction,
    },
    ListProfiles,
    ListControls,
    CliProfileTransaction {
        request: CliProfileRequest,
    },
    ConfigurationStatus,
    BeginConfigurationDraft {
        #[serde(rename = "expectedConfigurationRevision")]
        expected_configuration_revision: u64,
    },
    GetConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
    },
    EditConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
        #[serde(rename = "expectedDraftRevision")]
        expected_draft_revision: u64,
        #[serde(rename = "operationID")]
        operation_id: String,
        operation: ConfigurationOperation,
    },
    RebaseConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
        #[serde(rename = "expectedDraftRevision")]
        expected_draft_revision: u64,
        #[serde(rename = "expectedConfigurationRevision")]
        expected_configuration_revision: u64,
        #[serde(rename = "rebaseID")]
        rebase_id: String,
    },
    ValidateConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
        #[serde(rename = "expectedDraftRevision")]
        expected_draft_revision: u64,
    },
    PreviewConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
        #[serde(rename = "expectedDraftRevision")]
        expected_draft_revision: u64,
    },
    SaveConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
        #[serde(rename = "expectedDraftRevision")]
        expected_draft_revision: u64,
        #[serde(rename = "expectedConfigurationRevision")]
        expected_configuration_revision: u64,
        #[serde(rename = "commitID")]
        commit_id: String,
    },
    DiscardConfigurationDraft {
        #[serde(rename = "draftID")]
        draft_id: String,
        #[serde(rename = "expectedDraftRevision")]
        expected_draft_revision: u64,
    },
    RenderController,
    SelectProfile {
        #[serde(rename = "profileID")]
        profile_id: String,
    },
    PressControl {
        #[serde(rename = "controlID")]
        control_id: String,
    },
    ReleaseAll,
    Stop,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AccessibilityAction {
    Status,
    Prompt,
    Open,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostStatus {
    pub pid: u32,
    pub version: String,
    pub port: u16,
    pub requested_port: u16,
    pub bonjour: BonjourInfo,
    pub service_name: String,
    pub urls: Vec<String>,
    pub accessibility_trusted: bool,
    pub input_enabled: bool,
    pub configuration_write_enabled: bool,
    pub state_path: String,
    pub control_socket: String,
    #[serde(rename = "serverID")]
    pub server_id: String,
    pub pairing_code: String,
    pub core: StatusSnapshot,
    pub output: OutputSnapshot,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProfileSummary {
    pub id: String,
    pub name: String,
    pub active: bool,
    pub default: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigurationStatusSummary {
    pub configuration_revision: u64,
    pub profile_count: usize,
    #[serde(rename = "activeProfileID")]
    pub active_profile_id: String,
    #[serde(rename = "defaultProfileID")]
    pub default_profile_id: String,
    pub maximum_live_drafts: usize,
    pub draft_lifetime_millis: i64,
    pub operation_schema_version: u32,
    pub bridge_available: bool,
    pub configuration_write_enabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigurationDraftSummary {
    #[serde(rename = "draftID")]
    pub draft_id: String,
    pub base_configuration_revision: u64,
    pub draft_revision: u64,
    pub profile_count: usize,
    #[serde(rename = "activeProfileID")]
    pub active_profile_id: String,
    #[serde(rename = "defaultProfileID")]
    pub default_profile_id: String,
    pub operation_count: usize,
    pub created_at: i64,
    pub updated_at: i64,
    pub expires_at: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigurationValidationSummary {
    #[serde(rename = "draftID")]
    pub draft_id: String,
    pub draft_revision: u64,
    pub valid: bool,
    pub error_count: u32,
    pub warning_count: u32,
    pub validator: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigurationSaveSummary {
    #[serde(rename = "draftID")]
    pub draft_id: String,
    #[serde(rename = "commitID")]
    pub commit_id: String,
    pub base_configuration_revision: u64,
    pub configuration_revision: u64,
    pub draft_revision: u64,
    pub changed: bool,
    pub idempotent_replay: bool,
    pub phone_sync_queued: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ControlSummary {
    #[serde(rename = "controlID")]
    pub control_id: String,
    pub label: String,
    pub kind: String,
    pub part: KeypadElementInputPart,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ControlResponse {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expected_revision: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub actual_revision: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub conflict_paths: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<HostStatus>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pairing_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rotated: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub accessibility_trusted: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub profiles: Option<Vec<ProfileSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub controls: Option<Vec<ControlSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cli_profile: Option<CliProfileResponse>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub controller: Option<ControllerSnapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub editable_variant: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub configuration: Option<ConfigurationStatusSummary>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub configuration_revision: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub draft: Option<ConfigurationDraftSummary>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub draft_operation: Option<ConfigurationOperationOutcome>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub idempotent_replay: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub validation: Option<ConfigurationValidationSummary>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub save: Option<ConfigurationSaveSummary>,
    #[serde(skip_serializing_if = "Option::is_none", rename = "discardedDraftID")]
    pub discarded_draft_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", rename = "activeProfileID")]
    pub active_profile_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", rename = "selectedProfileID")]
    pub selected_profile_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", rename = "pressedControlID")]
    pub pressed_control_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub profile_changed: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stopping: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub released: Option<bool>,
}

impl ControlResponse {
    pub fn success() -> Self {
        Self {
            ok: true,
            error: None,
            error_code: None,
            expected_revision: None,
            actual_revision: None,
            conflict_paths: None,
            status: None,
            pairing_code: None,
            rotated: None,
            accessibility_trusted: None,
            profiles: None,
            controls: None,
            cli_profile: None,
            controller: None,
            editable_variant: None,
            configuration: None,
            configuration_revision: None,
            draft: None,
            draft_operation: None,
            idempotent_replay: None,
            validation: None,
            save: None,
            discarded_draft_id: None,
            active_profile_id: None,
            selected_profile_id: None,
            pressed_control_id: None,
            profile_changed: None,
            stopping: None,
            released: None,
        }
    }

    pub fn error(error: impl Into<String>) -> Self {
        Self {
            ok: false,
            error: Some(error.into()),
            ..Self::success()
        }
    }

    pub fn coded_error(code: impl Into<String>, error: impl Into<String>) -> Self {
        Self {
            ok: false,
            error: Some(error.into()),
            error_code: Some(code.into()),
            ..Self::success()
        }
    }

    pub fn revision_conflict(
        code: impl Into<String>,
        error: impl Into<String>,
        expected: u64,
        actual: u64,
    ) -> Self {
        Self {
            ok: false,
            error: Some(error.into()),
            error_code: Some(code.into()),
            expected_revision: Some(expected),
            actual_revision: Some(actual),
            ..Self::success()
        }
    }
}

pub trait ControlHandler: Send + Sync + 'static {
    fn handle(&self, request: ControlRequest) -> ControlResponse;
}

pub async fn bind_control_socket(path: &Path) -> Result<UnixListener, String> {
    let parent = path
        .parent()
        .ok_or_else(|| "control socket must have a parent directory".to_owned())?;
    if !parent.exists() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("create control socket directory: {error}"))?;
        fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
            .map_err(|error| format!("protect control socket directory: {error}"))?;
    }
    validate_control_directory(parent)?;
    clean_stale_socket(path).await?;
    let listener = UnixListener::bind(path)
        .map_err(|error| format!("bind control socket {}: {error}", path.display()))?;
    fs::set_permissions(path, fs::Permissions::from_mode(0o600))
        .map_err(|error| format!("protect control socket {}: {error}", path.display()))?;
    Ok(listener)
}

pub async fn serve_control(
    listener: UnixListener,
    handler: Arc<dyn ControlHandler>,
    mut shutdown: watch::Receiver<bool>,
) {
    let connection_limit = Arc::new(Semaphore::new(MAXIMUM_CONTROL_CONNECTIONS));
    let command_gate = Arc::new(Semaphore::new(1));
    loop {
        tokio::select! {
            changed = shutdown.changed() => {
                if changed.is_err() || *shutdown.borrow() {
                    break;
                }
            }
            accepted = listener.accept() => {
                match accepted {
                    Ok((stream, _)) => {
                        if verify_peer_user(&stream).is_err() {
                            continue;
                        }
                        let Ok(connection_permit) = Arc::clone(&connection_limit).try_acquire_owned() else {
                            continue;
                        };
                        let handler = Arc::clone(&handler);
                        let command_gate = Arc::clone(&command_gate);
                        tokio::spawn(async move {
                            let _connection_permit = connection_permit;
                            let _ = handle_connection(stream, handler, command_gate).await;
                        });
                    }
                    Err(_) => break,
                }
            }
        }
    }
}

async fn handle_connection(
    stream: UnixStream,
    handler: Arc<dyn ControlHandler>,
    command_gate: Arc<Semaphore>,
) -> Result<(), String> {
    let (read_half, mut write_half) = stream.into_split();
    let mut reader = BufReader::new(read_half);
    loop {
        let line = match tokio::time::timeout(CONTROL_LINE_TIMEOUT, read_bounded_line(&mut reader))
            .await
        {
            Ok(Ok(Some(line))) => line,
            Ok(Ok(None)) => return Ok(()),
            Ok(Err(BoundedLineError::TooLarge)) => {
                write_response(
                    &mut write_half,
                    &ControlResponse::error("control request is too large"),
                )
                .await?;
                return Ok(());
            }
            Ok(Err(BoundedLineError::Io(error))) => {
                return Err(format!("read control request: {error}"));
            }
            Err(_) => return Err("control request read timed out".to_owned()),
        };
        let response = match serde_json::from_slice::<ControlRequest>(&line) {
            Ok(request) => {
                let permit = match tokio::time::timeout(
                    CONTROL_ADMISSION_TIMEOUT,
                    Arc::clone(&command_gate).acquire_owned(),
                )
                .await
                {
                    Ok(Ok(permit)) => permit,
                    Ok(Err(_)) => return Ok(()),
                    Err(_) => {
                        write_response(
                            &mut write_half,
                            &ControlResponse::error("host control is busy; retry shortly"),
                        )
                        .await?;
                        continue;
                    }
                };
                let handler = Arc::clone(&handler);
                match tokio::task::spawn_blocking(move || {
                    let _permit = permit;
                    handler.handle(request)
                })
                .await
                {
                    Ok(response) => response,
                    Err(_) => ControlResponse::error("host control handler stopped unexpectedly"),
                }
            }
            Err(error) => ControlResponse::error(format!("invalid control request: {error}")),
        };
        write_response(&mut write_half, &response).await?;
    }
}

pub async fn send_request(
    path: &Path,
    request: &ControlRequest,
) -> Result<ControlResponse, String> {
    let operation = async {
        let mut stream = UnixStream::connect(path)
            .await
            .map_err(|error| format!("connect to host control socket: {error}"))?;
        verify_peer_user(&stream)?;
        let mut encoded = serde_json::to_vec(request)
            .map_err(|error| format!("encode control request: {error}"))?;
        encoded.push(b'\n');
        if encoded.len() > MAXIMUM_CONTROL_LINE {
            return Err("control request is too large".to_owned());
        }
        stream
            .write_all(&encoded)
            .await
            .map_err(|error| format!("write control request: {error}"))?;
        let mut reader = BufReader::new(stream);
        let response = match read_bounded_line(&mut reader).await {
            Ok(Some(response)) => response,
            Ok(None) => return Err("host closed the control socket without a response".to_owned()),
            Err(BoundedLineError::TooLarge) => {
                return Err("control response is too large".to_owned());
            }
            Err(BoundedLineError::Io(error)) => {
                return Err(format!("read control response: {error}"));
            }
        };
        serde_json::from_slice(&response)
            .map_err(|error| format!("decode control response: {error}"))
    };
    tokio::time::timeout(CONTROL_REQUEST_TIMEOUT, operation)
        .await
        .map_err(|_| "host control request timed out before completion".to_owned())?
}

async fn write_response(
    writer: &mut tokio::net::unix::OwnedWriteHalf,
    response: &ControlResponse,
) -> Result<(), String> {
    let mut encoded = serde_json::to_vec(response)
        .map_err(|error| format!("encode control response: {error}"))?;
    encoded.push(b'\n');
    if encoded.len() > MAXIMUM_CONTROL_LINE {
        encoded = serde_json::to_vec(&ControlResponse::error("control response is too large"))
            .map_err(|error| format!("encode bounded control response: {error}"))?;
        encoded.push(b'\n');
    }
    tokio::time::timeout(CONTROL_WRITE_TIMEOUT, writer.write_all(&encoded))
        .await
        .map_err(|_| "control response write timed out".to_owned())?
        .map_err(|error| format!("write control response: {error}"))
}

#[derive(Debug)]
enum BoundedLineError {
    TooLarge,
    Io(std::io::Error),
}

async fn read_bounded_line<R>(reader: &mut R) -> Result<Option<Vec<u8>>, BoundedLineError>
where
    R: AsyncBufRead + Unpin,
{
    let mut line = Vec::new();
    loop {
        let available = reader.fill_buf().await.map_err(BoundedLineError::Io)?;
        if available.is_empty() {
            return Ok((!line.is_empty()).then_some(line));
        }
        let consumed = available
            .iter()
            .position(|byte| *byte == b'\n')
            .map_or(available.len(), |position| position + 1);
        if line.len().saturating_add(consumed) > MAXIMUM_CONTROL_LINE {
            return Err(BoundedLineError::TooLarge);
        }
        let complete = available.get(consumed.saturating_sub(1)) == Some(&b'\n');
        line.extend_from_slice(&available[..consumed]);
        reader.consume(consumed);
        if complete {
            return Ok(Some(line));
        }
    }
}

fn validate_control_directory(path: &Path) -> Result<(), String> {
    let metadata = fs::symlink_metadata(path)
        .map_err(|error| format!("inspect control socket directory: {error}"))?;
    if metadata.file_type().is_symlink() || !metadata.file_type().is_dir() {
        return Err("control socket parent must be a real directory".to_owned());
    }
    if metadata.uid() != unsafe { libc::geteuid() } {
        return Err("control socket directory must be owned by the current user".to_owned());
    }
    if metadata.mode() & 0o077 != 0 {
        return Err(
            "control socket directory must not be accessible by group or other users".to_owned(),
        );
    }
    Ok(())
}

#[cfg(target_os = "macos")]
fn verify_peer_user(stream: &UnixStream) -> Result<(), String> {
    let mut user = 0;
    let mut group = 0;
    // SAFETY: getpeereid initializes both scalar outputs for a valid socket FD.
    let result = unsafe { libc::getpeereid(stream.as_raw_fd(), &mut user, &mut group) };
    if result != 0 {
        return Err(format!(
            "inspect control peer credentials: {}",
            std::io::Error::last_os_error()
        ));
    }
    if user != unsafe { libc::geteuid() } {
        return Err("control peer is not the current user".to_owned());
    }
    Ok(())
}

#[cfg(target_os = "linux")]
fn verify_peer_user(stream: &UnixStream) -> Result<(), String> {
    // SAFETY: getsockopt writes at most the supplied ucred size and updates its
    // length. The stream owns a live Unix-domain socket descriptor.
    unsafe {
        let mut credentials = std::mem::zeroed::<libc::ucred>();
        let mut length = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
        let result = libc::getsockopt(
            stream.as_raw_fd(),
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            (&mut credentials as *mut libc::ucred).cast(),
            &mut length,
        );
        if result != 0 || length as usize != std::mem::size_of::<libc::ucred>() {
            return Err(format!(
                "inspect control peer credentials: {}",
                std::io::Error::last_os_error()
            ));
        }
        if credentials.uid != libc::geteuid() {
            return Err("control peer is not the current user".to_owned());
        }
    }
    Ok(())
}

#[cfg(not(any(target_os = "macos", target_os = "linux")))]
fn verify_peer_user(_stream: &UnixStream) -> Result<(), String> {
    Err("control peer credential checks are unavailable on this platform".to_owned())
}

async fn clean_stale_socket(path: &Path) -> Result<(), String> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(format!("inspect control socket: {error}")),
    };
    if !metadata.file_type().is_socket() {
        return Err(format!(
            "refusing to replace non-socket control path {}",
            path.display()
        ));
    }
    if UnixStream::connect(path).await.is_ok() {
        return Err("another host is already answering on the control socket".to_owned());
    }
    fs::remove_file(path).map_err(|error| format!("remove stale control socket: {error}"))
}

pub fn remove_control_socket(path: &Path) {
    if fs::symlink_metadata(path).is_ok_and(|metadata| metadata.file_type().is_socket()) {
        let _ = fs::remove_file(path);
    }
}

pub fn socket_path(path: &Path) -> PathBuf {
    path.to_path_buf()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use tempfile::tempdir;

    struct PairingHandler;

    impl ControlHandler for PairingHandler {
        fn handle(&self, request: ControlRequest) -> ControlResponse {
            let ControlRequest::PairingCode { rotate } = request else {
                return ControlResponse::error("unexpected request");
            };
            let mut response = ControlResponse::success();
            response.pairing_code = Some("123456".to_owned());
            response.rotated = Some(rotate);
            response
        }
    }

    #[tokio::test]
    async fn unix_socket_serves_newline_delimited_request_and_response() {
        let directory = tempdir().unwrap();
        fs::set_permissions(directory.path(), fs::Permissions::from_mode(0o700)).unwrap();
        let path = directory.path().join("control.sock");
        let listener = bind_control_socket(&path).await.unwrap();
        let (shutdown_tx, shutdown_rx) = watch::channel(false);
        let server = tokio::spawn(serve_control(
            listener,
            Arc::new(PairingHandler),
            shutdown_rx,
        ));

        let response = send_request(&path, &ControlRequest::PairingCode { rotate: true })
            .await
            .unwrap();
        assert!(response.ok);
        assert_eq!(response.pairing_code.as_deref(), Some("123456"));
        assert_eq!(response.rotated, Some(true));

        shutdown_tx.send(true).unwrap();
        server.await.unwrap();
        remove_control_socket(&path);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn busy_request_is_rejected_without_late_execution() {
        struct SlowHandler(Arc<AtomicUsize>);
        impl ControlHandler for SlowHandler {
            fn handle(&self, _request: ControlRequest) -> ControlResponse {
                self.0.fetch_add(1, Ordering::SeqCst);
                std::thread::sleep(Duration::from_secs(1));
                ControlResponse::success()
            }
        }

        let directory = tempdir().unwrap();
        fs::set_permissions(directory.path(), fs::Permissions::from_mode(0o700)).unwrap();
        let path = directory.path().join("control.sock");
        let listener = bind_control_socket(&path).await.unwrap();
        let calls = Arc::new(AtomicUsize::new(0));
        let (shutdown_tx, shutdown_rx) = watch::channel(false);
        let server = tokio::spawn(serve_control(
            listener,
            Arc::new(SlowHandler(Arc::clone(&calls))),
            shutdown_rx,
        ));
        let first_path = path.clone();
        let first = tokio::spawn(async move {
            send_request(&first_path, &ControlRequest::Status)
                .await
                .unwrap()
        });
        for _ in 0..50 {
            if calls.load(Ordering::SeqCst) == 1 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        assert_eq!(calls.load(Ordering::SeqCst), 1);
        let busy = send_request(&path, &ControlRequest::Status).await.unwrap();
        assert!(!busy.ok);
        assert_eq!(
            busy.error.as_deref(),
            Some("host control is busy; retry shortly")
        );
        assert!(first.await.unwrap().ok);
        tokio::time::sleep(Duration::from_millis(100)).await;
        assert_eq!(calls.load(Ordering::SeqCst), 1);

        shutdown_tx.send(true).unwrap();
        server.await.unwrap();
        remove_control_socket(&path);
    }

    #[tokio::test]
    async fn typed_cli_profile_request_relays_over_same_user_control_ipc() {
        struct CliProfileHandler;
        impl ControlHandler for CliProfileHandler {
            fn handle(&self, request: ControlRequest) -> ControlResponse {
                let ControlRequest::CliProfileTransaction { request } = request else {
                    return ControlResponse::error("unexpected request");
                };
                let invocation = request.invocation_id.unwrap();
                let mut response = ControlResponse::success();
                response.cli_profile = Some(
                    crate::cli_profile::CliProfileResponse::authority_status(invocation, true),
                );
                response
            }
        }

        let directory = tempdir().unwrap();
        fs::set_permissions(directory.path(), fs::Permissions::from_mode(0o700)).unwrap();
        let path = directory.path().join("control.sock");
        let listener = bind_control_socket(&path).await.unwrap();
        let (shutdown_tx, shutdown_rx) = watch::channel(false);
        let server = tokio::spawn(serve_control(
            listener,
            Arc::new(CliProfileHandler),
            shutdown_rx,
        ));
        let invocation = uuid::Uuid::parse_str("00000000-0000-5000-8000-000000000601").unwrap();
        let response = send_request(
            &path,
            &ControlRequest::CliProfileTransaction {
                request: crate::cli_profile::CliProfileRequest {
                    schema_version: crate::cli_profile::CLI_PROFILE_SCHEMA_VERSION,
                    invocation_id: Some(invocation),
                    expected_configuration_revision: None,
                    command: crate::cli_profile::CliProfileCommand::List,
                },
            },
        )
        .await
        .unwrap();
        assert_eq!(response.cli_profile.unwrap().invocation_id, invocation);
        shutdown_tx.send(true).unwrap();
        server.await.unwrap();
        remove_control_socket(&path);
    }

    #[tokio::test]
    async fn insecure_existing_control_directory_is_rejected() {
        let directory = tempdir().unwrap();
        fs::set_permissions(directory.path(), fs::Permissions::from_mode(0o755)).unwrap();
        let error = bind_control_socket(&directory.path().join("control.sock"))
            .await
            .unwrap_err();
        assert!(error.contains("must not be accessible"));
    }

    #[tokio::test]
    async fn bounded_reader_rejects_a_newline_free_oversized_line() {
        let (mut writer, reader) = tokio::io::duplex(MAXIMUM_CONTROL_LINE * 2);
        let payload = vec![b'x'; MAXIMUM_CONTROL_LINE + 1];
        let write = tokio::spawn(async move { writer.write_all(&payload).await.unwrap() });
        let mut reader = BufReader::new(reader);
        assert!(matches!(
            read_bounded_line(&mut reader).await,
            Err(BoundedLineError::TooLarge)
        ));
        write.await.unwrap();
    }

    #[test]
    fn control_json_round_trip_is_newline_protocol_safe() {
        let request = ControlRequest::PairingCode { rotate: true };
        let json = serde_json::to_string(&request).unwrap();
        assert_eq!(json, r#"{"command":"pairing-code","rotate":true}"#);
        assert_eq!(
            serde_json::from_str::<ControlRequest>(&json).unwrap(),
            request
        );
        assert!(!json.contains('\n'));
    }

    #[test]
    fn profile_and_control_commands_use_opaque_ids() {
        let select = ControlRequest::SelectProfile {
            profile_id: "profile-a".to_owned(),
        };
        assert_eq!(
            serde_json::to_string(&select).unwrap(),
            r#"{"command":"select-profile","profileID":"profile-a"}"#
        );
        let press = ControlRequest::PressControl {
            control_id: "element:control-a#joystick_up".to_owned(),
        };
        let json = serde_json::to_string(&press).unwrap();
        assert_eq!(
            json,
            r#"{"command":"press-control","controlID":"element:control-a#joystick_up"}"#
        );
        assert_eq!(
            serde_json::from_str::<ControlRequest>(&json).unwrap(),
            press
        );
        assert!(!json.to_ascii_lowercase().contains("keycode"));
    }

    #[test]
    fn status_schema_does_not_have_an_auth_token_field() {
        let response = ControlResponse::success();
        let json = serde_json::to_string(&response).unwrap();
        assert!(!json.to_ascii_lowercase().contains("authtoken"));
        assert!(!json.to_ascii_lowercase().contains("realtimetoken"));
    }
}
