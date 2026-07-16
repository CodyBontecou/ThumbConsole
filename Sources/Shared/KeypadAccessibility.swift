import CoreGraphics
import Foundation

/// Platform-neutral accessibility text and value rules for runtime keypad controls.
/// Keeping these rules out of SwiftUI/UIKit makes them deterministic and testable.
struct KeypadAccessibility {
    struct PressEdge: Equatable {
        let isPressed: Bool
        let isActive: Bool
    }

    static let safeTapEdges = [
        PressEdge(isPressed: true, isActive: true),
        PressEdge(isPressed: false, isActive: false)
    ]

    static func label(visibleTitle: String?, fallback: String) -> String {
        let title = visibleTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? fallback : title
    }

    static func buttonHint(outputDescription: String?, fallbackOutputName: String) -> String {
        if let outputDescription, !outputDescription.isEmpty {
            return "Activates \(outputDescription)."
        }
        return "Sends the \(fallbackOutputName) input."
    }

    static func outputDescription(for binding: KeypadElementOutputBinding?) -> String? {
        guard let binding, !binding.isEmpty else { return nil }
        var outputs: [String] = []
        if let keyboard = binding.keyboard {
            outputs.append(keyboard.strokes.count > 1 ? "keyboard sequence" : "keyboard shortcut")
        }
        let gamepadNames = binding.gamepadButtons
            .map(\.displayName)
            .sorted()
        if !gamepadNames.isEmpty {
            outputs.append(gamepadNames.joined(separator: ", "))
        }
        return outputs.joined(separator: " and ")
    }

    static func percentValue(_ value: CGFloat) -> String {
        let clamped = min(max(value.isFinite ? value : 0, 0), 1)
        return "\(Int((clamped * 100).rounded())) percent"
    }

    static func adjustedValue(_ value: CGFloat, incrementing: Bool, step: CGFloat = 0.1) -> CGFloat {
        let safeValue = value.isFinite ? value : 0
        let safeStep = step.isFinite ? max(step, 0) : 0.1
        return min(max(safeValue + (incrementing ? safeStep : -safeStep), 0), 1)
    }

    static func joystickValue(
        horizontal: CGFloat,
        vertical: CGFloat,
        activeDirections: Set<GamepadJoystickDirection>
    ) -> String {
        guard !activeDirections.isEmpty || abs(horizontal) > 0.01 || abs(vertical) > 0.01 else {
            return "Centered"
        }
        let ordered = GamepadJoystickDirection.allCases
            .filter(activeDirections.contains)
            .map(\.displayName)
        if !ordered.isEmpty {
            return ordered.joined(separator: ", ")
        }
        return "Horizontal \(signedPercent(horizontal)), vertical \(signedPercent(vertical))"
    }

    static func joystickHint(outputSettings: GamepadJoystickOutputSettings) -> String {
        let settings = outputSettings.normalized
        var outputs: [String] = []
        if settings.analogTarget != .none {
            outputs.append(settings.analogTarget.displayName)
        }
        if settings.sendsDigitalDirections {
            outputs.append("digital directions")
        }
        let suffix = outputs.isEmpty ? "" : " Output: \(outputs.joined(separator: " and "))."
        return "Use the Up, Down, Left, and Right actions.\(suffix)"
    }

    static func identifier(kind: String, elementID: UUID?, fallback: String) -> String {
        let suffix = elementID?.uuidString.lowercased() ?? slug(fallback)
        return "keypad.\(slug(kind)).\(suffix)"
    }

    static func visualLabelScale(isAccessibilitySize: Bool) -> CGFloat {
        isAccessibilitySize ? 1.12 : 1
    }

    private static func signedPercent(_ value: CGFloat) -> String {
        let clamped = min(max(value.isFinite ? value : 0, -1), 1)
        return "\(Int((clamped * 100).rounded())) percent"
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        }
        return String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }
}
