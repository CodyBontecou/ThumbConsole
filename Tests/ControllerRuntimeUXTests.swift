import XCTest

final class ControllerRuntimeUXTests: XCTestCase {
    func testConnectionViewCanOverrideConnectedKeypad() {
        XCTAssertFalse(
            ControllerRuntimeChromePolicy.shouldShowControllerPad(
                prefersConnectionView: true,
                isConnected: true,
                canViewSavedKeypadOffline: true
            )
        )
        XCTAssertTrue(
            ControllerRuntimeChromePolicy.shouldShowControllerPad(
                prefersConnectionView: false,
                isConnected: true,
                canViewSavedKeypadOffline: false
            )
        )
    }

    func testOfflineKeypadInteractionRequiresPracticeOrEditing() {
        XCTAssertFalse(
            ControllerRuntimeChromePolicy.isKeypadInteractionActive(
                isConnected: false,
                isPracticeModeEnabled: false,
                isEditingLayout: false
            )
        )
        XCTAssertTrue(
            ControllerRuntimeChromePolicy.isKeypadInteractionActive(
                isConnected: false,
                isPracticeModeEnabled: true,
                isEditingLayout: false
            )
        )
        XCTAssertTrue(
            ControllerRuntimeChromePolicy.isKeypadInteractionActive(
                isConnected: false,
                isPracticeModeEnabled: false,
                isEditingLayout: true
            )
        )
    }

    func testTopBarIsPinnedWhileOfflineOrEditing() {
        XCTAssertTrue(ControllerRuntimeChromePolicy.shouldPinTopBar(isConnected: false, isEditingLayout: false))
        XCTAssertTrue(ControllerRuntimeChromePolicy.shouldPinTopBar(isConnected: true, isEditingLayout: true))
        XCTAssertFalse(ControllerRuntimeChromePolicy.shouldPinTopBar(isConnected: true, isEditingLayout: false))
        XCTAssertTrue(
            ControllerRuntimeChromePolicy.resolvedTopBarVisibility(
                requestedVisibility: false,
                isConnected: false,
                isEditingLayout: false
            )
        )
    }

    func testImmersiveSystemUIRequiresVisibleControllerAndPreference() {
        XCTAssertTrue(
            ControllerRuntimeChromePolicy.shouldHideSystemOverlays(
                isShowingController: true,
                userPrefersImmersiveMode: true
            )
        )
        XCTAssertFalse(
            ControllerRuntimeChromePolicy.shouldHideSystemOverlays(
                isShowingController: true,
                userPrefersImmersiveMode: false
            )
        )
        XCTAssertFalse(
            ControllerRuntimeChromePolicy.shouldHideSystemOverlays(
                isShowingController: false,
                userPrefersImmersiveMode: true
            )
        )
    }

    func testOnlySameTrustedClientMayReplaceActiveConnection() {
        XCTAssertTrue(
            ControllerConnectionAdmissionPolicy.permitsActiveClientReplacement(
                activeAuthToken: "trusted-phone",
                incomingAuthToken: " trusted-phone "
            )
        )
        XCTAssertFalse(
            ControllerConnectionAdmissionPolicy.permitsActiveClientReplacement(
                activeAuthToken: "trusted-phone",
                incomingAuthToken: "other-phone"
            )
        )
        XCTAssertFalse(
            ControllerConnectionAdmissionPolicy.permitsActiveClientReplacement(
                activeAuthToken: "trusted-phone",
                incomingAuthToken: nil
            )
        )
    }

    func testEditSessionUndoAndResetUseEntrySnapshot() {
        var entry = GamepadCustomization.defaultValue
        let session = GamepadLayoutEditSession(entrySnapshot: entry)

        entry.showsButtonLabels = false
        XCTAssertTrue(session.commit(entry))
        XCTAssertTrue(session.canUndo)
        XCTAssertTrue(session.hasChanges)

        var undone: GamepadCustomization?
        XCTAssertTrue(session.undo { undone = $0 })
        XCTAssertEqual(undone?.showsButtonLabels, true)
        XCTAssertFalse(session.hasChanges)

        entry.accentStyle = .purple
        XCTAssertTrue(session.commit(entry))
        var reset: GamepadCustomization?
        session.resetToEntry { reset = $0 }
        XCTAssertEqual(reset?.accentStyle, .monochrome)
        XCTAssertFalse(session.canUndo)
        XCTAssertFalse(session.hasChanges)
    }

    func testEditSessionIgnoresTimestampOnlyCommits() {
        let entry = GamepadCustomization.defaultValue
        var timestampOnly = entry
        timestampOnly.updatedAt = 42
        let session = GamepadLayoutEditSession(entrySnapshot: entry)

        XCTAssertFalse(session.commit(timestampOnly))
        XCTAssertFalse(session.canUndo)
        XCTAssertFalse(session.hasChanges)
    }
}
