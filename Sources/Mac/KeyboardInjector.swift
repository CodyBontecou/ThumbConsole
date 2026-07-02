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
        post(stroke: MacKeyStroke(keyCode: binding.keyCode, modifiers: binding.modifiers), keyDown: true)
    }

    func keyUp(_ binding: MacKeyBinding) {
        post(stroke: MacKeyStroke(keyCode: binding.keyCode, modifiers: binding.modifiers), keyDown: false)
    }

    func tapSequence(_ binding: MacKeyBinding) {
        for stroke in binding.strokes {
            tap(stroke)
        }
    }

    private func tap(_ stroke: MacKeyStroke) {
        post(stroke: stroke, keyDown: true)
        post(stroke: stroke, keyDown: false)
    }

    private func post(stroke: MacKeyStroke, keyDown: Bool) {
        guard cachedAccessibilityTrusted else { return }
        let event = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: keyDown)
        event?.flags = stroke.cgEventFlags(keyDown: keyDown)
        event?.post(tap: .cghidEventTap)
    }
}
