use serde_json::Value;
use thumble_core::minimal_default_profile;

#[test]
fn minimal_profile_matches_shared_swift_fixture() {
    let fixture: Value =
        serde_json::from_str(include_str!("../../../fixtures/state/minimal-profile.json"))
            .expect("minimal profile fixture must be valid JSON");

    assert_eq!(minimal_default_profile(), fixture);
}
