use crate::control::ConfigurationSaveSummary;
use crate::drafts::{DraftError, DraftStore};
use thumble_core::{ConfigurationCommitRecord, PersistentState};
use uuid::Uuid;

/// A fully validated configuration commit candidate. Callers must persist
/// `candidate` before activating it. A replay has no candidate to persist.
#[derive(Debug)]
pub(crate) struct PreparedConfigurationCommit {
    pub candidate: Option<PersistentState>,
    pub summary: ConfigurationSaveSummary,
}

#[derive(Debug)]
pub(crate) enum ConfigurationCommitError {
    InvalidCommitIdentity,
    InvalidRequestDigest,
    CommitIdConflict,
    ConfigurationRevisionConflict { expected: u64, actual: u64 },
    Draft(DraftError),
    InvalidConfiguration(String),
}

pub(crate) struct ConfigurationCommitInput<'a> {
    pub draft_id: &'a str,
    pub expected_draft_revision: u64,
    pub expected_configuration_revision: u64,
    pub commit_id: &'a str,
    pub client_request_digest: Option<&'a str>,
    pub now_millis: i64,
}

/// Shared compare-and-swap preparation used by the live host and standalone
/// authority path. It preserves credentials and unknown state fields, records
/// deterministic replay identity, and never mutates the supplied state.
pub(crate) fn prepare_configuration_commit(
    current: &PersistentState,
    store: &DraftStore,
    input: ConfigurationCommitInput<'_>,
) -> Result<PreparedConfigurationCommit, ConfigurationCommitError> {
    let ConfigurationCommitInput {
        draft_id,
        expected_draft_revision,
        expected_configuration_revision,
        commit_id,
        client_request_digest,
        now_millis,
    } = input;
    let draft_id = canonical_uuid(draft_id)?;
    let commit_id = canonical_uuid(commit_id)?;
    let client_request_digest = client_request_digest
        .map(validate_request_digest)
        .transpose()?
        .map(str::to_owned);

    if let Some(record) = current.recent_configuration_commit(&commit_id) {
        return committed_replay(
            record,
            &draft_id,
            expected_draft_revision,
            expected_configuration_revision,
            client_request_digest.as_deref(),
        )
        .map(|summary| PreparedConfigurationCommit {
            candidate: None,
            summary,
        });
    }

    let draft = store
        .get_at_revision(&draft_id, expected_draft_revision, now_millis)
        .map_err(ConfigurationCommitError::Draft)?;
    if draft.base_configuration_revision != expected_configuration_revision {
        return Err(ConfigurationCommitError::ConfigurationRevisionConflict {
            expected: expected_configuration_revision,
            actual: draft.base_configuration_revision,
        });
    }
    draft
        .working_document
        .validate()
        .map_err(|error| ConfigurationCommitError::InvalidConfiguration(error.to_string()))?;
    let draft_digest = DraftStore::operation_digest(&draft.working_document)
        .map_err(ConfigurationCommitError::Draft)?;

    if current.configuration_revision != expected_configuration_revision {
        return Err(ConfigurationCommitError::ConfigurationRevisionConflict {
            expected: expected_configuration_revision,
            actual: current.configuration_revision,
        });
    }

    let changed = draft.working_document != draft.base_document;
    let mut candidate = current.clone();
    if changed {
        draft
            .working_document
            .install_into(&mut candidate)
            .map_err(|error| ConfigurationCommitError::InvalidConfiguration(error.to_string()))?;
        candidate
            .bump_configuration_revision()
            .map_err(|error| ConfigurationCommitError::InvalidConfiguration(error.to_string()))?;
        candidate.configuration_updated_at = now_millis;
    }
    let result_revision = candidate.configuration_revision;
    candidate.record_configuration_commit(ConfigurationCommitRecord {
        commit_id: commit_id.clone(),
        draft_id: draft_id.clone(),
        base_configuration_revision: expected_configuration_revision,
        result_configuration_revision: result_revision,
        draft_revision: expected_draft_revision,
        draft_digest,
        client_request_digest,
        committed_at: now_millis,
    });
    candidate
        .normalize()
        .map_err(|error| ConfigurationCommitError::InvalidConfiguration(error.to_string()))?;

    Ok(PreparedConfigurationCommit {
        candidate: Some(candidate),
        summary: ConfigurationSaveSummary {
            draft_id,
            commit_id,
            base_configuration_revision: expected_configuration_revision,
            configuration_revision: result_revision,
            draft_revision: expected_draft_revision,
            changed,
            idempotent_replay: false,
            phone_sync_queued: false,
        },
    })
}

fn committed_replay(
    record: &ConfigurationCommitRecord,
    draft_id: &str,
    expected_draft_revision: u64,
    expected_configuration_revision: u64,
    client_request_digest: Option<&str>,
) -> Result<ConfigurationSaveSummary, ConfigurationCommitError> {
    if record.draft_id != draft_id
        || record.draft_revision != expected_draft_revision
        || record.base_configuration_revision != expected_configuration_revision
        || client_request_digest.is_some()
            && record.client_request_digest.as_deref() != client_request_digest
    {
        return Err(ConfigurationCommitError::CommitIdConflict);
    }
    Ok(ConfigurationSaveSummary {
        draft_id: record.draft_id.clone(),
        commit_id: record.commit_id.clone(),
        base_configuration_revision: record.base_configuration_revision,
        configuration_revision: record.result_configuration_revision,
        draft_revision: record.draft_revision,
        changed: record.result_configuration_revision != record.base_configuration_revision,
        idempotent_replay: true,
        phone_sync_queued: false,
    })
}

fn canonical_uuid(value: &str) -> Result<String, ConfigurationCommitError> {
    Uuid::parse_str(value)
        .map(|id| id.hyphenated().to_string())
        .map_err(|_| ConfigurationCommitError::InvalidCommitIdentity)
}

fn validate_request_digest(value: &str) -> Result<&str, ConfigurationCommitError> {
    if value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(value)
    } else {
        Err(ConfigurationCommitError::InvalidRequestDigest)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::paths::HostPaths;
    use tempfile::tempdir;

    #[test]
    fn deterministic_request_digest_reuse_conflicts_when_content_changes() {
        let root = tempdir().unwrap();
        let paths = HostPaths::new(root.path().to_path_buf(), root.path().join("control.sock"));
        let state = PersistentState::minimal("server").unwrap();
        let store = DraftStore::new(&paths);
        let draft_id = "00000000-0000-0000-0000-000000000701";
        let commit_id = "00000000-0000-0000-0000-000000000702";
        let digest = "a".repeat(64);
        let draft = store.begin_with_id(&state, 1, draft_id, 1).unwrap();
        let prepared = prepare_configuration_commit(
            &state,
            &store,
            ConfigurationCommitInput {
                draft_id,
                expected_draft_revision: draft.draft_revision,
                expected_configuration_revision: 1,
                commit_id,
                client_request_digest: Some(&digest),
                now_millis: 2,
            },
        )
        .unwrap();
        let committed = prepared.candidate.unwrap();
        let replay = prepare_configuration_commit(
            &committed,
            &store,
            ConfigurationCommitInput {
                draft_id,
                expected_draft_revision: draft.draft_revision,
                expected_configuration_revision: 1,
                commit_id,
                client_request_digest: Some(&digest),
                now_millis: 3,
            },
        )
        .unwrap();
        assert!(replay.candidate.is_none());
        assert!(replay.summary.idempotent_replay);
        assert!(matches!(
            prepare_configuration_commit(
                &committed,
                &store,
                ConfigurationCommitInput {
                    draft_id,
                    expected_draft_revision: draft.draft_revision,
                    expected_configuration_revision: 1,
                    commit_id,
                    client_request_digest: Some(&"b".repeat(64)),
                    now_millis: 3,
                },
            ),
            Err(ConfigurationCommitError::CommitIdConflict)
        ));
    }
}
