import CoreGraphics
import XCTest

final class KeypadAccessibilityTests: XCTestCase {
    func testVisibleCustomTitleWinsAndBlankTitleFallsBack() {
        XCTAssertEqual(KeypadAccessibility.label(visibleTitle: "  Fire  ", fallback: "Action 1"), "Fire")
        XCTAssertEqual(KeypadAccessibility.label(visibleTitle: "  ", fallback: "Action 1"), "Action 1")
        XCTAssertEqual(KeypadAccessibility.label(visibleTitle: nil, fallback: "Pause"), "Pause")
    }

    func testOutputDescriptionAndButtonHintExposeUsefulBinding() {
        let binding = KeypadElementOutputBinding(
            keyboard: KeypadKeyboardBinding(
                keyCode: 0,
                sequence: [
                    KeypadKeyboardStrokeBinding(keyCode: 0),
                    KeypadKeyboardStrokeBinding(keyCode: 1)
                ]
            ),
            gamepadButtons: [.south, .rightShoulder]
        )

        let description = KeypadAccessibility.outputDescription(for: binding)
        XCTAssertEqual(description, "keyboard sequence and Right Shoulder / R1, South / A / Cross")
        XCTAssertEqual(
            KeypadAccessibility.buttonHint(outputDescription: description, fallbackOutputName: "Action 1"),
            "Activates keyboard sequence and Right Shoulder / R1, South / A / Cross."
        )
        XCTAssertEqual(
            KeypadAccessibility.buttonHint(outputDescription: nil, fallbackOutputName: "Pause"),
            "Sends the Pause input."
        )
    }

    func testPercentageFormattingAndAdjustmentsClamp() {
        XCTAssertEqual(KeypadAccessibility.percentValue(-1), "0 percent")
        XCTAssertEqual(KeypadAccessibility.percentValue(0.556), "56 percent")
        XCTAssertEqual(KeypadAccessibility.percentValue(2), "100 percent")
        XCTAssertEqual(KeypadAccessibility.adjustedValue(0.95, incrementing: true), 1, accuracy: 0.001)
        XCTAssertEqual(KeypadAccessibility.adjustedValue(0.04, incrementing: false), 0, accuracy: 0.001)
        XCTAssertEqual(KeypadAccessibility.adjustedValue(0.4, incrementing: true), 0.5, accuracy: 0.001)
    }

    func testJoystickValueAndHintAreDeterministic() {
        XCTAssertEqual(
            KeypadAccessibility.joystickValue(horizontal: 0, vertical: 0, activeDirections: []),
            "Centered"
        )
        XCTAssertEqual(
            KeypadAccessibility.joystickValue(horizontal: -0.8, vertical: -0.8, activeDirections: [.left, .up]),
            "Up, Left"
        )
        XCTAssertEqual(
            KeypadAccessibility.joystickHint(
                outputSettings: GamepadJoystickOutputSettings(
                    analogTarget: .leftStick,
                    sendsDigitalDirections: true
                )
            ),
            "Use the Up, Down, Left, and Right actions. Output: Left analog stick and digital directions."
        )
    }

    func testIdentifiersAndSafeTapEdgesAreStable() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        XCTAssertEqual(
            KeypadAccessibility.identifier(kind: "Custom Button", elementID: id, fallback: "Ignored"),
            "keypad.custom-button.00000000-0000-0000-0000-000000000123"
        )
        XCTAssertEqual(
            KeypadAccessibility.identifier(kind: "Button", elementID: nil, fallback: "Fire / Jump"),
            "keypad.button.fire-jump"
        )
        XCTAssertEqual(
            KeypadAccessibility.safeTapEdges,
            [
                .init(isPressed: true, isActive: true),
                .init(isPressed: false, isActive: false)
            ]
        )
        XCTAssertEqual(KeypadAccessibility.visualLabelScale(isAccessibilitySize: false), 1)
        XCTAssertGreaterThan(KeypadAccessibility.visualLabelScale(isAccessibilitySize: true), 1)
    }
}
