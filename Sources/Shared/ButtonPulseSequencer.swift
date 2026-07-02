import Foundation

enum ButtonPulseCommand: Equatable {
    case send(GameButton, ButtonPressState)
    case scheduleRelease(GameButton, delayNanoseconds: UInt64)
    case schedulePress(GameButton, delayNanoseconds: UInt64)
}

struct ButtonPulseSequencer {
    // Keep synthesized tap edges visible across a 60 FPS game frame without
    // letting rapid same-button bursts back up behind overly conservative holds.
    static let actionGameMinimumTapDurationNanoseconds: UInt64 = 22_000_000
    static let actionGameMinimumInterTapGapNanoseconds: UInt64 = 18_000_000

    private struct QueuedPress {
        let pressIdentifier: UInt64?
        var isPhysicallyHeld: Bool
        let emitsWhenReleased: Bool
    }

    private enum PhysicalHoldRelease {
        case active
        case pending
        case queued
        case none
    }

    let minimumTapDurationNanoseconds: UInt64
    let minimumInterTapGapNanoseconds: UInt64

    private var pressedButtons: Set<GameButton> = []
    private var pressStartUptime: [GameButton: UInt64] = [:]
    private var activePhysicalPressIdentifiers: [GameButton: Set<UInt64>] = [:]
    private var activeAnonymousPhysicalHoldButtons: Set<GameButton> = []
    private var pendingReleaseButtons: Set<GameButton> = []
    private var pendingPressButtons: Set<GameButton> = []
    private var pendingPressPhysicalIdentifiers: [GameButton: UInt64] = [:]
    private var pendingAnonymousPressPhysicalHoldButtons: Set<GameButton> = []
    private var pendingPressEmitsWhenReleased: [GameButton: Bool] = [:]
    private var queuedPresses: [GameButton: [QueuedPress]] = [:]

    init(
        minimumTapDurationNanoseconds: UInt64,
        minimumInterTapGapNanoseconds: UInt64
    ) {
        self.minimumTapDurationNanoseconds = minimumTapDurationNanoseconds
        self.minimumInterTapGapNanoseconds = minimumInterTapGapNanoseconds
    }

    mutating func setButton(
        _ button: GameButton,
        pressed: Bool,
        pressIdentifier: UInt64? = nil,
        now: UInt64
    ) -> [ButtonPulseCommand] {
        if pressed {
            if pendingReleaseButtons.contains(button) || pendingPressButtons.contains(button) {
                enqueuePress(button, pressIdentifier: pressIdentifier, isPhysicallyHeld: true)
                return []
            }

            if pressedButtons.contains(button) {
                enqueuePress(button, pressIdentifier: pressIdentifier, isPhysicallyHeld: true)
                return releaseButton(button, respectingMinimumDuration: true, now: now)
            }

            return startPress(
                button,
                pressIdentifier: pressIdentifier,
                isPhysicallyHeld: true,
                now: now
            )
        }

        let releasedPhysicalHold = releasePhysicalHold(for: button, pressIdentifier: pressIdentifier)
        guard !pendingReleaseButtons.contains(button),
              !pendingPressButtons.contains(button)
        else { return [] }
        if pressIdentifier == nil {
            guard !hasPhysicalPress(button) else { return [] }
        } else {
            guard releasedPhysicalHold == .active else { return [] }
        }

        return releaseButton(button, respectingMinimumDuration: true, now: now)
    }

    mutating func recoverMissingReleaseBeforePress(
        _ button: GameButton,
        pressIdentifier: UInt64? = nil,
        now: UInt64
    ) -> [ButtonPulseCommand] {
        if let pressIdentifier {
            _ = removeActivePhysicalHold(for: button, pressIdentifier: pressIdentifier)
        } else {
            clearActivePhysicalHold(for: button)
        }

        if pendingReleaseButtons.contains(button) || pendingPressButtons.contains(button) {
            enqueuePress(button, pressIdentifier: pressIdentifier, isPhysicallyHeld: true)
            return []
        }

        if pressedButtons.contains(button) {
            enqueuePress(button, pressIdentifier: pressIdentifier, isPhysicallyHeld: true)
            return releaseButton(button, respectingMinimumDuration: true, now: now)
        }

        return startPress(
            button,
            pressIdentifier: pressIdentifier,
            isPhysicallyHeld: true,
            now: now
        )
    }

    mutating func recoverMissingPressBeforeRelease(
        _ button: GameButton,
        pressIdentifier: UInt64? = nil,
        now: UInt64
    ) -> [ButtonPulseCommand] {
        if pendingReleaseButtons.contains(button) || pendingPressButtons.contains(button) {
            enqueuePress(button, pressIdentifier: pressIdentifier, isPhysicallyHeld: false)
            return []
        }

        if pressedButtons.contains(button) {
            enqueuePress(button, pressIdentifier: pressIdentifier, isPhysicallyHeld: false)
            return releaseButton(button, respectingMinimumDuration: true, now: now)
        }

        var commands = startPress(
            button,
            pressIdentifier: pressIdentifier,
            isPhysicallyHeld: false,
            now: now
        )
        commands += releaseButton(button, respectingMinimumDuration: true, now: now)
        return commands
    }

    mutating func releaseTimerFired(for button: GameButton, now: UInt64) -> [ButtonPulseCommand] {
        guard pendingReleaseButtons.remove(button) != nil else { return [] }
        return finishRelease(button)
    }

    mutating func pressTimerFired(for button: GameButton, now: UInt64) -> [ButtonPulseCommand] {
        guard pendingPressButtons.remove(button) != nil else { return [] }
        let pressIdentifier = pendingPressPhysicalIdentifiers.removeValue(forKey: button)
        let hasAnonymousPhysicalHold = pendingAnonymousPressPhysicalHoldButtons.remove(button) != nil
        let emitsWhenReleased = pendingPressEmitsWhenReleased.removeValue(forKey: button) ?? true
        let hasPhysicalHold = pressIdentifier != nil || hasAnonymousPhysicalHold
        guard !pressedButtons.contains(button) else { return [] }

        if !hasPhysicalHold, !emitsWhenReleased {
            return scheduleQueuedPressIfNeeded(for: button)
        }

        var commands = startPress(
            button,
            pressIdentifier: pressIdentifier,
            isPhysicallyHeld: hasPhysicalHold,
            now: now
        )
        if !hasPhysicalHold {
            commands += releaseButton(button, respectingMinimumDuration: true, now: now)
        }
        return commands
    }

    mutating func reset() {
        pressedButtons.removeAll()
        pressStartUptime.removeAll()
        activePhysicalPressIdentifiers.removeAll()
        activeAnonymousPhysicalHoldButtons.removeAll()
        pendingReleaseButtons.removeAll()
        pendingPressButtons.removeAll()
        pendingPressPhysicalIdentifiers.removeAll()
        pendingAnonymousPressPhysicalHoldButtons.removeAll()
        pendingPressEmitsWhenReleased.removeAll()
        queuedPresses.removeAll()
    }

    func isPressed(_ button: GameButton) -> Bool {
        pressedButtons.contains(button)
    }

    func hasPhysicalPress(_ button: GameButton) -> Bool {
        activeAnonymousPhysicalHoldButtons.contains(button)
            || activePhysicalPressIdentifiers[button]?.isEmpty == false
            || pendingAnonymousPressPhysicalHoldButtons.contains(button)
            || pendingPressPhysicalIdentifiers[button] != nil
            || queuedPresses[button]?.contains(where: \.isPhysicallyHeld) == true
    }

    func hasPhysicalPress(_ button: GameButton, pressIdentifier: UInt64?) -> Bool {
        guard let pressIdentifier else {
            return hasPhysicalPress(button)
        }

        return activePhysicalPressIdentifiers[button]?.contains(pressIdentifier) == true
            || pendingPressPhysicalIdentifiers[button] == pressIdentifier
            || queuedPresses[button]?.contains {
                $0.pressIdentifier == pressIdentifier && $0.isPhysicallyHeld
            } == true
    }

    private mutating func releaseButton(
        _ button: GameButton,
        respectingMinimumDuration: Bool,
        now: UInt64
    ) -> [ButtonPulseCommand] {
        guard pressedButtons.contains(button) else { return [] }
        guard !respectingMinimumDuration || !pendingReleaseButtons.contains(button) else { return [] }

        let startedAt = pressStartUptime[button] ?? now
        let elapsed = now >= startedAt ? now - startedAt : minimumTapDurationNanoseconds

        if respectingMinimumDuration, elapsed < minimumTapDurationNanoseconds {
            let remaining = minimumTapDurationNanoseconds - elapsed
            pendingReleaseButtons.insert(button)
            return [.scheduleRelease(button, delayNanoseconds: remaining)]
        }

        return finishRelease(button)
    }

    private mutating func startPress(
        _ button: GameButton,
        pressIdentifier: UInt64?,
        isPhysicallyHeld: Bool,
        now: UInt64
    ) -> [ButtonPulseCommand] {
        pressStartUptime[button] = now
        pressedButtons.insert(button)
        if isPhysicallyHeld {
            markActivePhysicalHold(for: button, pressIdentifier: pressIdentifier)
        }
        return [.send(button, .down)]
    }

    private mutating func finishRelease(_ button: GameButton) -> [ButtonPulseCommand] {
        guard pressedButtons.contains(button) else { return [] }

        let shouldResumeInterruptedHold = queuedPresses[button]?.isEmpty == false
        let interruptedPhysicalPressIdentifiers = shouldResumeInterruptedHold
            ? activePhysicalPressIdentifiers[button, default: []]
            : []

        pendingReleaseButtons.remove(button)
        pressStartUptime[button] = nil
        pressedButtons.remove(button)
        clearActivePhysicalHold(for: button)

        for pressIdentifier in interruptedPhysicalPressIdentifiers {
            enqueuePress(
                button,
                pressIdentifier: pressIdentifier,
                isPhysicallyHeld: true,
                emitsWhenReleased: false
            )
        }

        var commands: [ButtonPulseCommand] = [.send(button, .up)]
        commands += scheduleQueuedPressIfNeeded(for: button)
        return commands
    }

    private mutating func scheduleQueuedPressIfNeeded(for button: GameButton) -> [ButtonPulseCommand] {
        guard !pendingPressButtons.contains(button) else { return [] }

        var nextQueuedPress: QueuedPress?
        while let queuedPress = dequeuePress(for: button) {
            if queuedPress.isPhysicallyHeld || queuedPress.emitsWhenReleased {
                nextQueuedPress = queuedPress
                break
            }
        }

        guard let queuedPress = nextQueuedPress else { return [] }

        pendingPressButtons.insert(button)
        pendingPressEmitsWhenReleased[button] = queuedPress.emitsWhenReleased
        if queuedPress.isPhysicallyHeld {
            if let pressIdentifier = queuedPress.pressIdentifier {
                pendingPressPhysicalIdentifiers[button] = pressIdentifier
                pendingAnonymousPressPhysicalHoldButtons.remove(button)
            } else {
                pendingPressPhysicalIdentifiers[button] = nil
                pendingAnonymousPressPhysicalHoldButtons.insert(button)
            }
        } else {
            pendingPressPhysicalIdentifiers[button] = nil
            pendingAnonymousPressPhysicalHoldButtons.remove(button)
        }
        return [.schedulePress(button, delayNanoseconds: minimumInterTapGapNanoseconds)]
    }

    private mutating func enqueuePress(
        _ button: GameButton,
        pressIdentifier: UInt64?,
        isPhysicallyHeld: Bool,
        emitsWhenReleased: Bool = true
    ) {
        queuedPresses[button, default: []].append(
            QueuedPress(
                pressIdentifier: pressIdentifier,
                isPhysicallyHeld: isPhysicallyHeld,
                emitsWhenReleased: emitsWhenReleased
            )
        )
    }

    private mutating func dequeuePress(for button: GameButton) -> QueuedPress? {
        guard var queue = queuedPresses[button], !queue.isEmpty else { return nil }
        let press = queue.removeFirst()
        queuedPresses[button] = queue.isEmpty ? nil : queue
        return press
    }

    private mutating func releasePhysicalHold(
        for button: GameButton,
        pressIdentifier: UInt64?
    ) -> PhysicalHoldRelease {
        if let pressIdentifier {
            if removeActivePhysicalHold(for: button, pressIdentifier: pressIdentifier) {
                return .active
            }

            if pendingPressPhysicalIdentifiers[button] == pressIdentifier {
                pendingPressPhysicalIdentifiers[button] = nil
                return .pending
            }

            return releaseQueuedPhysicalHold(for: button) { queuedPress in
                queuedPress.pressIdentifier == pressIdentifier
            }
        }

        if activeAnonymousPhysicalHoldButtons.remove(button) != nil {
            return .active
        }

        if pendingAnonymousPressPhysicalHoldButtons.remove(button) != nil {
            return .pending
        }

        return releaseQueuedPhysicalHold(for: button) { queuedPress in
            queuedPress.pressIdentifier == nil
        }
    }

    @discardableResult
    private mutating func releaseQueuedPhysicalHold(
        for button: GameButton,
        matching predicate: (QueuedPress) -> Bool
    ) -> PhysicalHoldRelease {
        guard var queue = queuedPresses[button],
              let heldIndex = queue.firstIndex(where: { $0.isPhysicallyHeld && predicate($0) })
        else {
            return .none
        }

        if queue[heldIndex].emitsWhenReleased {
            queue[heldIndex].isPhysicallyHeld = false
        } else {
            queue.remove(at: heldIndex)
        }
        queuedPresses[button] = queue
        return .queued
    }

    private mutating func markActivePhysicalHold(
        for button: GameButton,
        pressIdentifier: UInt64?
    ) {
        guard let pressIdentifier else {
            activeAnonymousPhysicalHoldButtons.insert(button)
            return
        }

        activePhysicalPressIdentifiers[button, default: []].insert(pressIdentifier)
        activeAnonymousPhysicalHoldButtons.remove(button)
    }

    @discardableResult
    private mutating func removeActivePhysicalHold(
        for button: GameButton,
        pressIdentifier: UInt64
    ) -> Bool {
        guard var identifiers = activePhysicalPressIdentifiers[button],
              identifiers.remove(pressIdentifier) != nil
        else {
            return false
        }

        activePhysicalPressIdentifiers[button] = identifiers.isEmpty ? nil : identifiers
        return true
    }

    private mutating func clearActivePhysicalHold(for button: GameButton) {
        activePhysicalPressIdentifiers[button] = nil
        activeAnonymousPhysicalHoldButtons.remove(button)
    }
}
