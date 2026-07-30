use serde_json::{Map, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::error::Error;
use std::fmt;
use thumble_core::ConfigurationDocument;

const MAXIMUM_MERGE_PATHS: usize = 128;
const MAXIMUM_MERGE_PATH_BYTES: usize = 512;

#[derive(Debug, Clone, PartialEq)]
pub struct ConfigurationMergeResult {
    pub document: ConfigurationDocument,
    pub changed_paths: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConfigurationMergeConflict {
    pub paths: Vec<String>,
}

pub fn merge_configuration_documents(
    base: &ConfigurationDocument,
    draft: &ConfigurationDocument,
    current: &ConfigurationDocument,
) -> Result<ConfigurationMergeResult, ConfigurationMergeConflict> {
    let base = serde_json::to_value(base).map_err(|_| conflict("/"))?;
    let draft = serde_json::to_value(draft).map_err(|_| conflict("/"))?;
    let current = serde_json::to_value(current).map_err(|_| conflict("/"))?;
    let mut changed_paths = Vec::new();
    let merged = merge_value(
        Some(&base),
        Some(&draft),
        Some(&current),
        "",
        &mut changed_paths,
    )?
    .ok_or_else(|| conflict("/"))?;
    let document: ConfigurationDocument =
        serde_json::from_value(merged).map_err(|_| conflict("/"))?;
    document.validate().map_err(|_| conflict("/"))?;
    changed_paths.sort();
    changed_paths.dedup();
    if changed_paths.len() > MAXIMUM_MERGE_PATHS {
        changed_paths.truncate(MAXIMUM_MERGE_PATHS);
    }
    Ok(ConfigurationMergeResult {
        document,
        changed_paths,
    })
}

fn merge_value(
    base: Option<&Value>,
    draft: Option<&Value>,
    current: Option<&Value>,
    path: &str,
    changed_paths: &mut Vec<String>,
) -> Result<Option<Value>, ConfigurationMergeConflict> {
    if draft == base {
        return Ok(current.cloned());
    }
    if current == base {
        record_changed(path, changed_paths);
        return Ok(draft.cloned());
    }
    if draft == current {
        return Ok(draft.cloned());
    }

    match (base, draft, current) {
        (Some(Value::Object(base)), Some(Value::Object(draft)), Some(Value::Object(current))) => {
            merge_objects(base, draft, current, path, changed_paths).map(Some)
        }
        (Some(Value::Array(base)), Some(Value::Array(draft)), Some(Value::Array(current))) => {
            if arrays_are_keyed(base, draft, current) {
                merge_keyed_arrays(base, draft, current, path, changed_paths).map(Some)
            } else {
                Err(conflict(path))
            }
        }
        _ => Err(conflict(path)),
    }
}

fn merge_objects(
    base: &Map<String, Value>,
    draft: &Map<String, Value>,
    current: &Map<String, Value>,
    path: &str,
    changed_paths: &mut Vec<String>,
) -> Result<Value, ConfigurationMergeConflict> {
    let keys = base
        .keys()
        .chain(draft.keys())
        .chain(current.keys())
        .cloned()
        .collect::<BTreeSet<_>>();
    let mut result = Map::new();
    let mut conflicts = Vec::new();
    for key in keys {
        let child_path = join_path(path, &key);
        match merge_value(
            base.get(&key),
            draft.get(&key),
            current.get(&key),
            &child_path,
            changed_paths,
        ) {
            Ok(Some(value)) => {
                result.insert(key, value);
            }
            Ok(None) => {
                record_changed(&child_path, changed_paths);
            }
            Err(conflict) => conflicts.extend(conflict.paths),
        }
    }
    if conflicts.is_empty() {
        Ok(Value::Object(result))
    } else {
        Err(ConfigurationMergeConflict {
            paths: bounded_paths(conflicts),
        })
    }
}

fn arrays_are_keyed(base: &[Value], draft: &[Value], current: &[Value]) -> bool {
    let nonempty = [base, draft, current]
        .into_iter()
        .filter(|values| !values.is_empty())
        .collect::<Vec<_>>();
    !nonempty.is_empty()
        && nonempty
            .into_iter()
            .all(|values| keyed_entries(values).is_some())
}

fn merge_keyed_arrays(
    base: &[Value],
    draft: &[Value],
    current: &[Value],
    path: &str,
    changed_paths: &mut Vec<String>,
) -> Result<Value, ConfigurationMergeConflict> {
    let base_entries = keyed_entries(base).ok_or_else(|| conflict(path))?;
    let draft_entries = keyed_entries(draft).ok_or_else(|| conflict(path))?;
    let current_entries = keyed_entries(current).ok_or_else(|| conflict(path))?;
    let base_order = base_entries.keys_in_order();
    let draft_order = draft_entries.keys_in_order();
    let current_order = current_entries.keys_in_order();
    let draft_reordered = relative_order_changed(&base_order, &draft_order);
    let current_reordered = relative_order_changed(&base_order, &current_order);
    if draft_reordered
        && current_reordered
        && common_order(&draft_order, &current_order) != common_order(&current_order, &draft_order)
    {
        return Err(conflict(path));
    }

    let mut order = if draft_reordered && !current_reordered {
        draft_order.clone()
    } else {
        current_order.clone()
    };
    for id in draft_order.iter().chain(current_order.iter()) {
        if !order.contains(id) {
            order.push(id.clone());
        }
    }

    let all_ids = base_order
        .iter()
        .chain(draft_order.iter())
        .chain(current_order.iter())
        .cloned()
        .collect::<BTreeSet<_>>();
    let mut merged = BTreeMap::new();
    let mut conflicts = Vec::new();
    for id in all_ids {
        let display_id = current_entries
            .display_id(&id)
            .or_else(|| draft_entries.display_id(&id))
            .or_else(|| base_entries.display_id(&id))
            .unwrap_or(&id);
        let child_path = join_path(path, display_id);
        match merge_value(
            base_entries.value(&id),
            draft_entries.value(&id),
            current_entries.value(&id),
            &child_path,
            changed_paths,
        ) {
            Ok(Some(value)) => {
                merged.insert(id, value);
            }
            Ok(None) => record_changed(&child_path, changed_paths),
            Err(conflict) => conflicts.extend(conflict.paths),
        }
    }
    if !conflicts.is_empty() {
        return Err(ConfigurationMergeConflict {
            paths: bounded_paths(conflicts),
        });
    }
    if draft_reordered && !current_reordered {
        record_changed(path, changed_paths);
    }
    Ok(Value::Array(
        order
            .into_iter()
            .filter_map(|id| merged.remove(&id))
            .collect(),
    ))
}

struct KeyedEntries<'a> {
    ordered: Vec<(String, &'a str, &'a Value)>,
}

impl<'a> KeyedEntries<'a> {
    fn keys_in_order(&self) -> Vec<String> {
        self.ordered.iter().map(|entry| entry.0.clone()).collect()
    }

    fn value(&self, id: &str) -> Option<&'a Value> {
        self.ordered
            .iter()
            .find_map(|entry| (entry.0 == id).then_some(entry.2))
    }

    fn display_id(&self, id: &str) -> Option<&'a str> {
        self.ordered
            .iter()
            .find_map(|entry| (entry.0 == id).then_some(entry.1))
    }
}

fn keyed_entries(values: &[Value]) -> Option<KeyedEntries<'_>> {
    let mut seen = BTreeSet::new();
    let mut ordered = Vec::with_capacity(values.len());
    for value in values {
        let id = value.get("id")?.as_str()?;
        if id.is_empty() || id.len() > 128 {
            return None;
        }
        let key = id.to_ascii_lowercase();
        if !seen.insert(key.clone()) {
            return None;
        }
        ordered.push((key, id, value));
    }
    Some(KeyedEntries { ordered })
}

fn relative_order_changed(base: &[String], candidate: &[String]) -> bool {
    let candidate_set = candidate.iter().collect::<BTreeSet<_>>();
    let base_common = base
        .iter()
        .filter(|id| candidate_set.contains(id))
        .collect::<Vec<_>>();
    let base_set = base.iter().collect::<BTreeSet<_>>();
    let candidate_common = candidate
        .iter()
        .filter(|id| base_set.contains(id))
        .collect::<Vec<_>>();
    base_common != candidate_common
}

fn common_order(left: &[String], right: &[String]) -> Vec<String> {
    let right_set = right.iter().collect::<BTreeSet<_>>();
    left.iter()
        .filter(|id| right_set.contains(id))
        .cloned()
        .collect()
}

fn record_changed(path: &str, changed_paths: &mut Vec<String>) {
    if changed_paths.len() < MAXIMUM_MERGE_PATHS {
        changed_paths.push(bounded_path(path));
    }
}

fn conflict(path: &str) -> ConfigurationMergeConflict {
    ConfigurationMergeConflict {
        paths: vec![bounded_path(path)],
    }
}

fn bounded_paths(paths: Vec<String>) -> Vec<String> {
    let mut paths = paths
        .into_iter()
        .map(|path| bounded_path(&path))
        .collect::<Vec<_>>();
    paths.sort();
    paths.dedup();
    paths.truncate(MAXIMUM_MERGE_PATHS);
    paths
}

fn bounded_path(path: &str) -> String {
    let path = if path.is_empty() { "/" } else { path };
    path.chars().take(MAXIMUM_MERGE_PATH_BYTES).collect()
}

fn join_path(parent: &str, component: &str) -> String {
    let escaped = component.replace('~', "~0").replace('/', "~1");
    if parent.is_empty() {
        format!("/{escaped}")
    } else {
        format!("{parent}/{escaped}")
    }
}

impl fmt::Display for ConfigurationMergeConflict {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.paths.is_empty() {
            formatter.write_str("configuration draft conflicts with the current configuration")
        } else {
            write!(
                formatter,
                "configuration draft conflicts at {}",
                self.paths.join(", ")
            )
        }
    }
}

impl Error for ConfigurationMergeConflict {}

#[cfg(test)]
mod tests {
    use super::*;
    use thumble_core::{ConfigurationDocument, PersistentState};

    fn document() -> ConfigurationDocument {
        ConfigurationDocument::from_state(&PersistentState::minimal("server").unwrap()).unwrap()
    }

    #[test]
    fn disjoint_profile_and_future_field_changes_merge_losslessly() {
        let base = document();
        let mut draft = base.clone();
        let mut current = base.clone();
        draft.profiles[0]["name"] = Value::String("Draft Name".to_owned());
        current.profiles[0]["futureField"] = serde_json::json!({"newer": true});
        let merged = merge_configuration_documents(&base, &draft, &current).unwrap();
        assert_eq!(merged.document.profiles[0]["name"], "Draft Name");
        assert_eq!(merged.document.profiles[0]["futureField"]["newer"], true);
    }

    #[test]
    fn same_scalar_changed_differently_reports_exact_path() {
        let base = document();
        let mut draft = base.clone();
        let mut current = base.clone();
        draft.profiles[0]["name"] = Value::String("Draft".to_owned());
        current.profiles[0]["name"] = Value::String("Current".to_owned());
        let conflict = merge_configuration_documents(&base, &draft, &current).unwrap_err();
        assert!(conflict.paths.iter().any(|path| path.ends_with("/name")));
    }

    #[test]
    fn keyed_element_arrays_merge_disjoint_nested_edits() {
        let base = document();
        let mut draft = base.clone();
        let mut current = base.clone();
        draft.profiles[0]["customization"]["elements"][0]["label"] =
            Value::String("Draft Up".to_owned());
        current.profiles[0]["customization"]["elements"][1]["future"] = Value::Bool(true);
        let merged = merge_configuration_documents(&base, &draft, &current).unwrap();
        assert_eq!(
            merged.document.profiles[0]["customization"]["elements"][0]["label"],
            "Draft Up"
        );
        assert_eq!(
            merged.document.profiles[0]["customization"]["elements"][1]["future"],
            true
        );
    }

    #[test]
    fn delete_versus_edit_of_same_keyed_entity_conflicts() {
        let base = document();
        let mut draft = base.clone();
        let mut current = base.clone();
        draft.profiles[0]["customization"]["elements"]
            .as_array_mut()
            .unwrap()
            .remove(0);
        current.profiles[0]["customization"]["elements"][0]["label"] =
            Value::String("Current Up".to_owned());
        assert!(merge_configuration_documents(&base, &draft, &current).is_err());
    }
}
