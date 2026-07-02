import SwiftUI
import UIKit

struct TouchCaptureView: UIViewRepresentable {
    var onPressedChanged: (Bool) -> Void

    func makeUIView(context: Context) -> TouchCaptureUIView {
        let view = TouchCaptureUIView()
        view.onPressedChanged = onPressedChanged
        return view
    }

    func updateUIView(_ uiView: TouchCaptureUIView, context: Context) {
        uiView.onPressedChanged = onPressedChanged
    }
}

final class TouchCaptureUIView: UIView {
    var onPressedChanged: ((Bool) -> Void)?

    private var activeTouches: Set<UITouch> = []
    private var isPressed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        updatePressedState(for: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updatePressedState(for: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        updatePressedStateFromActiveTouches()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        updatePressedStateFromActiveTouches()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            activeTouches.removeAll()
            setPressed(false)
        }
    }

    private func updatePressedState(for event: UIEvent?) {
        let touches = event?.touches(for: self) ?? activeTouches
        let anyInside = touches.contains { touch in
            guard touch.phase != .ended, touch.phase != .cancelled else { return false }
            return bounds.insetBy(dx: -8, dy: -8).contains(touch.location(in: self))
        }
        setPressed(anyInside)
    }

    private func updatePressedStateFromActiveTouches() {
        let anyInside = activeTouches.contains { touch in
            bounds.insetBy(dx: -8, dy: -8).contains(touch.location(in: self))
        }
        setPressed(anyInside)
    }

    private func setPressed(_ pressed: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        onPressedChanged?(pressed)
    }
}
