import Foundation

/// Pure policy for controller chrome that must never become unreachable.
public enum ControllerRuntimeChromePolicy {
    public static func shouldShowControllerPad(
        prefersConnectionView: Bool,
        isConnected: Bool,
        canViewSavedKeypadOffline: Bool
    ) -> Bool {
        !prefersConnectionView && (isConnected || canViewSavedKeypadOffline)
    }

    public static func isKeypadInteractionActive(
        isConnected: Bool,
        isPracticeModeEnabled: Bool,
        isEditingLayout: Bool
    ) -> Bool {
        isConnected || isPracticeModeEnabled || isEditingLayout
    }

    public static func shouldPinTopBar(isConnected: Bool, isEditingLayout: Bool) -> Bool {
        !isConnected || isEditingLayout
    }

    public static func resolvedTopBarVisibility(
        requestedVisibility: Bool,
        isConnected: Bool,
        isEditingLayout: Bool
    ) -> Bool {
        shouldPinTopBar(isConnected: isConnected, isEditingLayout: isEditingLayout)
            ? true
            : requestedVisibility
    }

    public static func shouldHideSystemOverlays(
        isShowingController: Bool,
        userPrefersImmersiveMode: Bool
    ) -> Bool {
        isShowingController && userPrefersImmersiveMode
    }
}

/// Admission policy for the Mac helper's single active iPhone session.
/// A reconnect may replace an existing socket only when both sockets prove they
/// belong to the same trusted installation. A different iPhone must never evict
/// the active keypad and trigger competing reconnect loops.
public enum ControllerConnectionAdmissionPolicy {
    public static func permitsActiveClientReplacement(
        activeAuthToken: String?,
        incomingAuthToken: String?
    ) -> Bool {
        guard let activeAuthToken = normalized(activeAuthToken),
              let incomingAuthToken = normalized(incomingAuthToken)
        else { return false }
        return activeAuthToken == incomingAuthToken
    }

    private static func normalized(_ token: String?) -> String? {
        guard let token else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Reference-semantic edit history for the iPhone's lightweight layout editor.
/// Keeping the large customization snapshots on the heap also protects the
/// controller's small realtime stack budget.
public final class GamepadLayoutEditSession: @unchecked Sendable {
    public let entrySnapshot: GamepadCustomization
    public private(set) var committedCustomization: GamepadCustomization
    private var undoSnapshots: [GamepadCustomization]

    public init(entrySnapshot: GamepadCustomization) {
        let snapshot = entrySnapshot.normalized
        self.entrySnapshot = snapshot
        self.committedCustomization = snapshot
        self.undoSnapshots = []
    }

    public var canUndo: Bool {
        !undoSnapshots.isEmpty
    }

    public var hasChanges: Bool {
        !committedCustomization.hasSamePresentation(as: entrySnapshot)
    }

    /// Records one completed gesture or delete operation. Intermediate drag
    /// updates should not be recorded, so one Undo reverses one user action.
    @discardableResult
    public func commit(_ customization: GamepadCustomization) -> Bool {
        let next = customization.normalized
        guard !next.hasSamePresentation(as: committedCustomization) else { return false }
        undoSnapshots.append(committedCustomization)
        committedCustomization = next
        return true
    }

    @discardableResult
    public func undo(apply: (GamepadCustomization) -> Void) -> Bool {
        guard let previous = undoSnapshots.popLast() else { return false }
        committedCustomization = previous
        apply(previous)
        return true
    }

    public func resetToEntry(apply: (GamepadCustomization) -> Void) {
        undoSnapshots.removeAll()
        committedCustomization = entrySnapshot
        apply(entrySnapshot)
    }
}
