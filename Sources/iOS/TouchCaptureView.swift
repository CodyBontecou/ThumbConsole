import SwiftUI
import UIKit

struct TouchCaptureView: UIViewRepresentable {
    var onPressEdge: (_ pressed: Bool, _ isActive: Bool, _ pressIdentifier: UInt64) -> Void

    func makeUIView(context: Context) -> TouchCaptureUIView {
        let view = TouchCaptureUIView()
        view.onPressEdge = onPressEdge
        return view
    }

    func updateUIView(_ uiView: TouchCaptureUIView, context: Context) {
        uiView.onPressEdge = onPressEdge
    }
}

struct TouchRoutingView: UIViewRepresentable {
    func makeUIView(context: Context) -> TouchRoutingUIView {
        TouchRoutingUIView()
    }

    func updateUIView(_ uiView: TouchRoutingUIView, context: Context) {}
}

final class TouchRoutingUIView: UIView {
    private weak var currentWindow: UIWindow?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            TouchCaptureUIView.route(touch, in: window)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            TouchCaptureUIView.route(touch, in: window)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            TouchCaptureUIView.deactivateGlobally(touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            TouchCaptureUIView.deactivateGlobally(touch)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            TouchCaptureUIView.deactivateTouches(in: currentWindow)
        }
        currentWindow = window
    }
}

final class TouchCaptureUIView: UIView {
    var onPressEdge: ((_ pressed: Bool, _ isActive: Bool, _ pressIdentifier: UInt64) -> Void)?

    private struct WeakTouchOwner {
        weak var view: TouchCaptureUIView?
    }

    private static let registeredViews = NSHashTable<TouchCaptureUIView>.weakObjects()
    private static var touchOwners: [ObjectIdentifier: WeakTouchOwner] = [:]
    private static var activePressIdentifiers: Set<UInt64> = []
    private static var nextTouchIdentifier: UInt64 = 1

    private var activeTouches: Set<UITouch> = []
    private var activeTouchIdentifiers: [UITouch: UInt64] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Self.registeredViews.remove(self)
        deactivateAllTouches()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            Self.route(touch, in: window)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            Self.route(touch, in: window)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            Self.deactivateGlobally(touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            Self.deactivateGlobally(touch)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            Self.registeredViews.remove(self)
            deactivateAllTouches()
        } else {
            Self.registeredViews.add(self)
        }
    }

    // Route through the shared registry so a touch that starts in empty controller
    // space or slides between adjacent buttons can still produce the intended edges.
    fileprivate static func route(_ touch: UITouch, in sourceWindow: UIWindow?) {
        guard touch.phase != .ended, touch.phase != .cancelled else {
            deactivateGlobally(touch)
            return
        }

        let previousOwner = owner(for: touch)
        guard let sourceWindow else {
            if let previousOwner {
                previousOwner.deactivateTouch(touch, clearsOwner: false)
            }
            clearOwner(for: touch)
            return
        }

        let windowLocation = touch.location(in: sourceWindow)
        if let previousOwner,
           previousOwner.containsTouch(at: windowLocation, in: sourceWindow)
        {
            return
        }

        let targetOwner = targetView(at: windowLocation, in: sourceWindow)

        if let previousOwner, previousOwner !== targetOwner {
            previousOwner.deactivateTouch(touch, clearsOwner: false)
        }

        guard let targetOwner else {
            clearOwner(for: touch)
            return
        }

        targetOwner.activateTouch(touch)
        setOwner(targetOwner, for: touch)
    }

    private func activateTouch(_ touch: UITouch) {
        guard activeTouches.insert(touch).inserted else { return }
        let pressIdentifier = Self.allocatePressIdentifier()
        activeTouchIdentifiers[touch] = pressIdentifier
        onPressEdge?(true, true, pressIdentifier)
    }

    private func deactivateTouch(_ touch: UITouch, clearsOwner: Bool = true) {
        guard activeTouches.remove(touch) != nil else { return }
        let pressIdentifier = activeTouchIdentifiers.removeValue(forKey: touch)
        if clearsOwner {
            Self.clearOwner(for: touch)
        }
        if let pressIdentifier {
            Self.releasePressIdentifier(pressIdentifier)
            onPressEdge?(false, !activeTouches.isEmpty, pressIdentifier)
        }
    }

    fileprivate static func deactivateGlobally(_ touch: UITouch) {
        if let owner = owner(for: touch) {
            owner.deactivateTouch(touch)
        }
    }

    fileprivate static func deactivateTouches(in window: UIWindow?) {
        guard let window else { return }
        var owners: [TouchCaptureUIView] = []
        for weakOwner in touchOwners.values {
            guard let owner = weakOwner.view,
                  owner.window === window
            else { continue }

            owners.append(owner)
        }

        for owner in owners {
            owner.deactivateAllTouches()
        }
    }

    static func deactivateAllRegisteredTouches() {
        for owner in registeredViews.allObjects {
            owner.deactivateAllTouches()
        }
        touchOwners.removeAll()
        activePressIdentifiers.removeAll()
    }

    private func deactivateAllTouches() {
        let touches = activeTouches
        activeTouches.removeAll()
        let touchIdentifiers = activeTouchIdentifiers
        activeTouchIdentifiers.removeAll()
        Self.touchOwners = Self.touchOwners.filter { $0.value.view !== self }
        guard !touches.isEmpty else { return }

        for touch in touches {
            if let pressIdentifier = touchIdentifiers[touch] {
                Self.releasePressIdentifier(pressIdentifier)
                onPressEdge?(false, false, pressIdentifier)
            }
        }
    }

    private static func owner(for touch: UITouch) -> TouchCaptureUIView? {
        let key = ObjectIdentifier(touch)
        guard let owner = touchOwners[key]?.view else {
            touchOwners[key] = nil
            return nil
        }
        return owner
    }

    private static func setOwner(_ owner: TouchCaptureUIView, for touch: UITouch) {
        touchOwners[ObjectIdentifier(touch)] = WeakTouchOwner(view: owner)
    }

    private static func clearOwner(for touch: UITouch) {
        touchOwners[ObjectIdentifier(touch)] = nil
    }

    private static func allocatePressIdentifier() -> UInt64 {
        var identifier = nextTouchIdentifier
        while activePressIdentifiers.contains(identifier) {
            identifier = nextIdentifier(after: identifier)
        }
        nextTouchIdentifier = nextIdentifier(after: identifier)
        activePressIdentifiers.insert(identifier)
        return identifier
    }

    private static func releasePressIdentifier(_ identifier: UInt64) {
        activePressIdentifiers.remove(identifier)
    }

    private static func nextIdentifier(after identifier: UInt64) -> UInt64 {
        if identifier >= ControllerWireCodec.maximumButtonPressIdentifier {
            return 1
        } else {
            return identifier + 1
        }
    }

    private func containsTouch(at windowLocation: CGPoint, in sourceWindow: UIWindow) -> Bool {
        guard canReceiveRoutedTouch(in: sourceWindow) else { return false }
        let localLocation = sourceWindow.convert(windowLocation, to: self)
        return bounds.contains(localLocation)
    }

    private func canReceiveRoutedTouch(in sourceWindow: UIWindow) -> Bool {
        window === sourceWindow
            && !isHidden
            && alpha > 0.01
            && isUserInteractionEnabled
            && bounds.width > 0
            && bounds.height > 0
    }

    private static func targetView(at windowLocation: CGPoint, in sourceWindow: UIWindow) -> TouchCaptureUIView? {
        var bestView: TouchCaptureUIView?
        var bestArea = CGFloat.greatestFiniteMagnitude
        let enumerator = registeredViews.objectEnumerator()

        while let view = enumerator.nextObject() as? TouchCaptureUIView {
            guard view.containsTouch(at: windowLocation, in: sourceWindow) else { continue }

            let area = view.bounds.width * view.bounds.height
            if area < bestArea {
                bestArea = area
                bestView = view
            }
        }

        return bestView
    }

}
