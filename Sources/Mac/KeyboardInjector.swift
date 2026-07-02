import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

final class KeyboardInjector {
    private let source: CGEventSource?
    private var cachedAccessibilityTrusted = AXIsProcessTrusted()

    init() {
        source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
    }

    var isAccessibilityTrusted: Bool {
        cachedAccessibilityTrusted
    }

    @discardableResult
    func refreshAccessibilityStatus() -> Bool {
        cachedAccessibilityTrusted = AXIsProcessTrusted()
        return cachedAccessibilityTrusted
    }

    @discardableResult
    func promptForAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func keyDown(_ keyCode: CGKeyCode) {
        post(keyCode: keyCode, keyDown: true)
    }

    func keyUp(_ keyCode: CGKeyCode) {
        post(keyCode: keyCode, keyDown: false)
    }

    private func post(keyCode: CGKeyCode, keyDown: Bool) {
        guard cachedAccessibilityTrusted else { return }
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        event?.post(tap: .cghidEventTap)
    }
}
