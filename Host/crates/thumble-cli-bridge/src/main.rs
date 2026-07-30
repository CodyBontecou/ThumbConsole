use std::fs;
use std::io::{self, Read, Write};
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use thumble_host::cli_profile::{
    execute_offline_authority, CliProfileCommand, CliProfileRequest, CliProfileResponse,
};
use thumble_host::control::{send_request, ControlRequest};
use thumble_host::paths::HostPaths;
use thumble_host::runtime::AuthorityLock;
use uuid::Uuid;

const MAXIMUM_REQUEST_BYTES: usize = 64 * 1024;
const MAXIMUM_RESPONSE_BYTES: usize = 256 * 1024;

fn main() {
    if std::env::args_os().len() != 1 {
        emit(&CliProfileResponse::transport_failure(
            Uuid::new_v4(),
            "none",
            "arguments_not_allowed",
            "thumble-cli-bridge accepts no command-line arguments",
        ));
        std::process::exit(2);
    }

    let mut request = match read_request()
        .and_then(|data| serde_json::from_slice::<CliProfileRequest>(&data).map_err(|_| ()))
    {
        Ok(request) => request,
        Err(()) => {
            emit(&CliProfileResponse::transport_failure(
                Uuid::new_v4(),
                "none",
                "invalid_request",
                "CLI helper requires one bounded newline-terminated typed JSON request",
            ));
            std::process::exit(2);
        }
    };
    let invocation_id = request.invocation_id.unwrap_or_else(Uuid::new_v4);
    request.invocation_id = Some(invocation_id);

    // The helper accepts no caller-selected state/control paths. Retain only a
    // securely owned, non-symlink HOME so tests and standard account homes can
    // derive the canonical Application Support location; clear everything else.
    let safe_home = sanitized_home();
    for key in std::env::vars_os().map(|(key, _)| key).collect::<Vec<_>>() {
        std::env::remove_var(key);
    }
    if let Some(home) = safe_home {
        std::env::set_var("HOME", home);
    }
    let paths = match HostPaths::discover() {
        Ok(paths) => paths,
        Err(_) => {
            emit(&CliProfileResponse::transport_failure(
                invocation_id,
                "none",
                "path_discovery_failed",
                "canonical Rust authority paths could not be discovered",
            ));
            std::process::exit(1);
        }
    };

    if matches!(request.command, CliProfileCommand::AuthorityStatus) {
        emit(&CliProfileResponse::authority_status(
            invocation_id,
            authority_artifacts_present(&paths),
        ));
        return;
    }

    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .worker_threads(1)
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(_) => {
            emit(&CliProfileResponse::transport_failure(
                invocation_id,
                "none",
                "runtime_failed",
                "CLI helper runtime could not be initialized",
            ));
            std::process::exit(1);
        }
    };
    let online = runtime.block_on(send_request(
        &paths.control_socket,
        &ControlRequest::CliProfileTransaction {
            request: request.clone(),
        },
    ));
    if let Ok(response) = online {
        if let Some(response) = response.cli_profile {
            emit(&response);
            if !response.ok {
                std::process::exit(1);
            }
            return;
        }
        emit(&CliProfileResponse::transport_failure(
            invocation_id,
            "online",
            "invalid_host_response",
            "live host returned no typed CLI profile response",
        ));
        std::process::exit(1);
    }

    let authority = match AuthorityLock::try_acquire(&paths) {
        Ok(Some(authority)) => authority,
        Ok(None) => {
            emit(&CliProfileResponse::transport_failure(
                invocation_id,
                "online",
                "authority_unreachable",
                "Rust authority lock is held but its same-user control socket is unreachable",
            ));
            std::process::exit(1);
        }
        Err(_) => {
            emit(&CliProfileResponse::transport_failure(
                invocation_id,
                "offline",
                "authority_lock_failed",
                "canonical Rust authority lock failed security validation",
            ));
            std::process::exit(1);
        }
    };
    let response = execute_offline_authority(&paths, &request);
    drop(authority);
    emit(&response);
    if !response.ok {
        std::process::exit(1);
    }
}

fn sanitized_home() -> Option<std::path::PathBuf> {
    let home = std::env::var_os("HOME").map(std::path::PathBuf::from)?;
    if !home.is_absolute() {
        return None;
    }
    let metadata = fs::symlink_metadata(&home).ok()?;
    (!metadata.file_type().is_symlink()
        && metadata.is_dir()
        && metadata.uid() == unsafe { libc::geteuid() }
        && metadata.permissions().mode() & 0o022 == 0)
        .then_some(home)
}

fn authority_artifacts_present(paths: &HostPaths) -> bool {
    if fs::symlink_metadata(&paths.state_file).is_ok() {
        return true;
    }
    if fs::symlink_metadata(&paths.control_socket)
        .is_ok_and(|metadata| metadata.file_type().is_socket() || metadata.file_type().is_symlink())
    {
        return true;
    }
    if paths.lock_file.exists() {
        return match AuthorityLock::try_acquire(paths) {
            Ok(Some(authority)) => {
                drop(authority);
                false
            }
            Ok(None) | Err(_) => true,
        };
    }
    false
}

fn read_request() -> Result<Vec<u8>, ()> {
    let mut input = Vec::new();
    io::stdin()
        .take((MAXIMUM_REQUEST_BYTES + 2) as u64)
        .read_to_end(&mut input)
        .map_err(|_| ())?;
    validate_request_frame(input)
}

fn validate_request_frame(mut input: Vec<u8>) -> Result<Vec<u8>, ()> {
    if input.is_empty() || input.len() > MAXIMUM_REQUEST_BYTES + 1 || input.last() != Some(&b'\n') {
        return Err(());
    }
    input.pop();
    if input.is_empty() || input.contains(&b'\n') || input.contains(&b'\r') {
        return Err(());
    }
    Ok(input)
}

fn emit(response: &CliProfileResponse) {
    let mut output = serde_json::to_vec(response).unwrap_or_else(|_| {
        br#"{"schemaVersion":5,"ok":false,"invocationID":"00000000-0000-0000-0000-000000000000","authorityMode":"none","error":{"code":"encoding_failed","message":"CLI helper response could not be encoded"}}"#.to_vec()
    });
    if output.len() > MAXIMUM_RESPONSE_BYTES {
        output = br#"{"schemaVersion":5,"ok":false,"invocationID":"00000000-0000-0000-0000-000000000000","authorityMode":"none","error":{"code":"response_too_large","message":"CLI helper response exceeds its bound"}}"#.to_vec();
    }
    output.push(b'\n');
    let _ = io::stdout().write_all(&output);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_frame_rejects_oversized_multiline_and_unterminated_input() {
        assert!(validate_request_frame(vec![b'x'; MAXIMUM_REQUEST_BYTES + 2]).is_err());
        assert!(validate_request_frame(b"{}\n{}\n".to_vec()).is_err());
        assert!(validate_request_frame(b"{}".to_vec()).is_err());
        assert_eq!(validate_request_frame(b"{}\n".to_vec()).unwrap(), b"{}");
    }

    #[test]
    fn typed_request_denies_unknown_fields_and_raw_paths() {
        let unknown =
            br#"{"schemaVersion":1,"command":{"type":"profile.list"},"statePath":"/tmp/state"}"#;
        assert!(serde_json::from_slice::<CliProfileRequest>(unknown).is_err());
        let raw_profile =
            br#"{"schemaVersion":1,"command":{"type":"profile.reset","target":null,"profile":{}}}"#;
        assert!(serde_json::from_slice::<CliProfileRequest>(raw_profile).is_err());
        let raw_orientation = br#"{"schemaVersion":1,"command":{"type":"orientation.copy","target":{"kind":"active"},"source":"landscape","destination":"portrait","automaticallyArrange":true,"profile":{"customization":{}},"statePath":"/tmp/state"}}"#;
        assert!(serde_json::from_slice::<CliProfileRequest>(raw_orientation).is_err());
    }
}
