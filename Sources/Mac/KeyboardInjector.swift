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

    func keyDown(_ binding: MacKeyBinding) {
        post(binding: binding, keyDown: true)
    }

    func keyUp(_ binding: MacKeyBinding) {
        post(binding: binding, keyDown: false)
    }

    private func post(binding: MacKeyBinding, keyDown: Bool) {
        guard cachedAccessibilityTrusted else { return }
        let event = CGEvent(keyboardEventSource: source, virtualKey: binding.keyCode, keyDown: keyDown)
        event?.flags = binding.cgEventFlags(keyDown: keyDown)
        event?.post(tap: .cghidEventTap)
    }
}
