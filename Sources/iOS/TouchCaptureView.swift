import SwiftUI
import UIKit

struct TouchCaptureView: UIViewRepresentable {
    var hitShape: GamepadButtonShapeStyle = .roundedRectangle
    var onPressEdge: (_ pressed: Bool, _ isActive: Bool, _ pressIdentifier: UInt64) -> Void

    func makeUIView(context: Context) -> TouchCaptureUIView {
        let view = TouchCaptureUIView()
        view.hitShape = hitShape
        view.onPressEdge = onPressEdge
        return view
    }

    func updateUIView(_ uiView: TouchCaptureUIView, context: Context) {
        uiView.hitShape = hitShape
        uiView.onPressEdge = onPressEdge
    }
}

struct JoystickCaptureView: UIViewRepresentable {
    var onDirectionEdge: (_ direction: GamepadJoystickDirection, _ pressed: Bool, _ pressIdentifier: UInt64) -> Void
    var onVectorChanged: (_ vector: CGVector, _ activeDirections: Set<GamepadJoystickDirection>) -> Void

    func makeUIView(context: Context) -> JoystickCaptureUIView {
        let view = JoystickCaptureUIView()
        view.onDirectionEdge = onDirectionEdge
        view.onVectorChanged = onVectorChanged
        return view
    }

    func updateUIView(_ uiView: JoystickCaptureUIView, context: Context) {
        uiView.onDirectionEdge = onDirectionEdge
        uiView.onVectorChanged = onVectorChanged
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
            route(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            route(touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            JoystickCaptureUIView.deactivateGlobally(touch)
            TouchCaptureUIView.deactivateGlobally(touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            JoystickCaptureUIView.deactivateGlobally(touch)
            TouchCaptureUIView.deactivateGlobally(touch)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            TouchCaptureUIView.deactivateTouches(in: currentWindow)
            JoystickCaptureUIView.deactivateTouches(in: currentWindow)
        }
        currentWindow = window
    }

    private func route(_ touch: UITouch) {
        if JoystickCaptureUIView.isTracking(touch) {
            JoystickCaptureUIView.route(touch, in: window)
            return
        }

        if TouchCaptureUIView.isTracking(touch) {
            if !TouchCaptureUIView.route(touch, in: window) {
                JoystickCaptureUIView.route(touch, in: window)
            }
            return
        }

        if !JoystickCaptureUIView.route(touch, in: window) {
            TouchCaptureUIView.route(touch, in: window)
        }
    }
}

fileprivate enum ControllerPressIdentifierAllocator {
    private static var activePressIdentifiers: Set<UInt64> = []
    private static var nextTouchIdentifier: UInt64 = 1

    static func allocate() -> UInt64 {
        var identifier = nextTouchIdentifier
        while activePressIdentifiers.contains(identifier) {
            identifier = nextIdentifier(after: identifier)
        }
        nextTouchIdentifier = nextIdentifier(after: identifier)
        activePressIdentifiers.insert(identifier)
        return identifier
    }

    static func release(_ identifier: UInt64) {
        activePressIdentifiers.remove(identifier)
    }

    static func reset() {
        activePressIdentifiers.removeAll()
        nextTouchIdentifier = 1
    }

    private static func nextIdentifier(after identifier: UInt64) -> UInt64 {
        if identifier >= ControllerWireCodec.maximumButtonPressIdentifier {
            return 1
        } else {
            return identifier + 1
        }
    }
}

final class TouchCaptureUIView: UIView {
    var hitShape: GamepadButtonShapeStyle = .roundedRectangle {
        didSet {
            guard oldValue != hitShape else { return }
            cachedHitPath = nil
            cachedHitPathShape = nil
        }
    }
    var onPressEdge: ((_ pressed: Bool, _ isActive: Bool, _ pressIdentifier: UInt64) -> Void)?

    private struct WeakTouchOwner {
        weak var view: TouchCaptureUIView?
    }

    private static let registeredViews = NSHashTable<TouchCaptureUIView>.weakObjects()
    private static var touchOwners: [ObjectIdentifier: WeakTouchOwner] = [:]
    private static let activeTouchRetentionOutset: CGFloat = 18

    private var activeTouches: Set<UITouch> = []
    private var activeTouchIdentifiers: [UITouch: UInt64] = [:]
    private var cachedHitPath: UIBezierPath?
    private var cachedHitPathBounds = CGRect.null
    private var cachedHitPathShape: GamepadButtonShapeStyle?

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
        containsLocalPoint(point, in: bounds)
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
    @discardableResult
    fileprivate static func route(_ touch: UITouch, in sourceWindow: UIWindow?) -> Bool {
        guard touch.phase != .ended, touch.phase != .cancelled else {
            deactivateGlobally(touch)
            return false
        }

        let previousOwner = owner(for: touch)
        guard let sourceWindow else {
            if let previousOwner {
                previousOwner.deactivateTouch(touch, clearsOwner: false)
            }
            clearOwner(for: touch)
            return false
        }

        let windowLocation = touch.location(in: sourceWindow)
        if let previousOwner,
           previousOwner.retainsActiveTouch(at: windowLocation, in: sourceWindow)
        {
            return true
        }

        let targetOwner = targetView(at: windowLocation, in: sourceWindow)

        if let previousOwner, previousOwner !== targetOwner {
            previousOwner.deactivateTouch(touch, clearsOwner: false)
        }

        guard let targetOwner else {
            clearOwner(for: touch)
            return false
        }

        targetOwner.activateTouch(touch)
        setOwner(targetOwner, for: touch)
        return true
    }

    private func activateTouch(_ touch: UITouch) {
        guard activeTouches.insert(touch).inserted else { return }
        let pressIdentifier = ControllerPressIdentifierAllocator.allocate()
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
            ControllerPressIdentifierAllocator.release(pressIdentifier)
            onPressEdge?(false, !activeTouches.isEmpty, pressIdentifier)
        }
    }

    fileprivate static func deactivateGlobally(_ touch: UITouch) {
        if let owner = owner(for: touch) {
            owner.deactivateTouch(touch)
        }
    }

    fileprivate static func isTracking(_ touch: UITouch) -> Bool {
        owner(for: touch) != nil
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
        JoystickCaptureUIView.deactivateAllRegisteredJoysticks()
        ControllerPressIdentifierAllocator.reset()
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
                ControllerPressIdentifierAllocator.release(pressIdentifier)
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

    private func containsTouch(at windowLocation: CGPoint, in sourceWindow: UIWindow) -> Bool {
        containsTouch(at: windowLocation, in: sourceWindow, outset: 0)
    }

    // Keep ownership slightly sticky once a touch has activated a control. A
    // thumb can drift a few points when a second finger presses another button;
    // without hysteresis that jitter can emit an accidental key-up and cut a
    // held jump/attack short.
    private func retainsActiveTouch(at windowLocation: CGPoint, in sourceWindow: UIWindow) -> Bool {
        containsTouch(at: windowLocation, in: sourceWindow, outset: Self.activeTouchRetentionOutset)
    }

    private func containsTouch(at windowLocation: CGPoint, in sourceWindow: UIWindow, outset: CGFloat) -> Bool {
        guard canReceiveRoutedTouch(in: sourceWindow) else { return false }
        let localLocation = sourceWindow.convert(windowLocation, to: self)
        let hitBounds = bounds.insetBy(dx: -outset, dy: -outset)
        return containsLocalPoint(localLocation, in: hitBounds)
    }

    private func containsLocalPoint(_ point: CGPoint, in hitBounds: CGRect) -> Bool {
        guard hitBounds.contains(point) else { return false }

        switch hitShape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            return true
        case .polygon:
            return hitPath(for: .polygon, in: hitBounds).contains(point)
        case .star:
            return hitPath(for: .star, in: hitBounds).contains(point)
        }
    }

    private func hitPath(for shape: GamepadButtonShapeStyle, in rect: CGRect) -> UIBezierPath {
        if cachedHitPathShape == shape,
           cachedHitPathBounds == rect,
           let cachedHitPath
        {
            return cachedHitPath
        }

        let path: UIBezierPath
        switch shape {
        case .polygon:
            path = regularPolygonPath(sides: 3, in: rect)
        case .star:
            path = starPath(points: 5, innerRadiusRatio: 0.45, in: rect)
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            path = UIBezierPath(rect: rect)
        }

        cachedHitPath = path
        cachedHitPathBounds = rect
        cachedHitPathShape = shape
        return path
    }

    private func regularPolygonPath(sides: Int, in rect: CGRect) -> UIBezierPath {
        let sideCount = max(3, sides)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let xRadius = rect.width / 2
        let yRadius = rect.height / 2
        let path = UIBezierPath()

        for index in 0..<sideCount {
            let angle = (-CGFloat.pi / 2) + (CGFloat(index) * 2 * CGFloat.pi / CGFloat(sideCount))
            let point = CGPoint(
                x: center.x + cos(angle) * xRadius,
                y: center.y + sin(angle) * yRadius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()
        return path
    }

    private func starPath(points: Int, innerRadiusRatio: CGFloat, in rect: CGRect) -> UIBezierPath {
        let pointCount = max(3, points)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerXRadius = rect.width / 2
        let outerYRadius = rect.height / 2
        let innerXRadius = outerXRadius * innerRadiusRatio
        let innerYRadius = outerYRadius * innerRadiusRatio
        let path = UIBezierPath()

        for index in 0..<(pointCount * 2) {
            let isOuterPoint = index.isMultiple(of: 2)
            let angle = (-CGFloat.pi / 2) + (CGFloat(index) * CGFloat.pi / CGFloat(pointCount))
            let point = CGPoint(
                x: center.x + cos(angle) * (isOuterPoint ? outerXRadius : innerXRadius),
                y: center.y + sin(angle) * (isOuterPoint ? outerYRadius : innerYRadius)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.close()
        return path
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

final class JoystickCaptureUIView: UIView {
    var onDirectionEdge: ((_ direction: GamepadJoystickDirection, _ pressed: Bool, _ pressIdentifier: UInt64) -> Void)?
    var onVectorChanged: ((_ vector: CGVector, _ activeDirections: Set<GamepadJoystickDirection>) -> Void)?

    private struct WeakJoystickOwner {
        weak var view: JoystickCaptureUIView?
    }

    private static let registeredViews = NSHashTable<JoystickCaptureUIView>.weakObjects()
    private static var touchOwners: [ObjectIdentifier: WeakJoystickOwner] = [:]
    private static let directionThreshold: CGFloat = 0.34

    private weak var activeTouch: UITouch?
    private var activeDirections: Set<GamepadJoystickDirection> = []
    private var activeDirectionIdentifiers: [GamepadJoystickDirection: UInt64] = [:]

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
        deactivateAllDirections()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        containsLocalPoint(point)
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
            deactivateTouch()
        } else {
            Self.registeredViews.add(self)
        }
    }

    @discardableResult
    fileprivate static func route(_ touch: UITouch, in sourceWindow: UIWindow?) -> Bool {
        guard touch.phase != .ended, touch.phase != .cancelled else {
            deactivateGlobally(touch)
            return false
        }

        let previousOwner = owner(for: touch)
        guard let sourceWindow else {
            previousOwner?.deactivateTouch(clearsOwner: false)
            clearOwner(for: touch)
            return previousOwner != nil
        }

        if let previousOwner {
            previousOwner.updateTouch(touch, in: sourceWindow)
            return true
        }

        let windowLocation = touch.location(in: sourceWindow)
        guard let targetOwner = targetView(at: windowLocation, in: sourceWindow) else {
            return false
        }

        guard targetOwner.activeTouch == nil else {
            return true
        }

        targetOwner.activateTouch(touch, in: sourceWindow)
        setOwner(targetOwner, for: touch)
        return true
    }

    fileprivate static func deactivateGlobally(_ touch: UITouch) {
        if let owner = owner(for: touch) {
            owner.deactivateTouch()
            clearOwner(for: touch)
        }
    }

    fileprivate static func isTracking(_ touch: UITouch) -> Bool {
        owner(for: touch) != nil
    }

    fileprivate static func deactivateTouches(in window: UIWindow?) {
        guard let window else { return }
        var owners: [JoystickCaptureUIView] = []
        for weakOwner in touchOwners.values {
            guard let owner = weakOwner.view,
                  owner.window === window
            else { continue }
            owners.append(owner)
        }

        for owner in owners {
            owner.deactivateTouch()
        }
    }

    fileprivate static func deactivateAllRegisteredJoysticks() {
        for owner in registeredViews.allObjects {
            owner.deactivateTouch()
        }
        touchOwners.removeAll()
    }

    private func activateTouch(_ touch: UITouch, in sourceWindow: UIWindow) {
        activeTouch = touch
        updateTouch(touch, in: sourceWindow)
    }

    private func updateTouch(_ touch: UITouch, in sourceWindow: UIWindow) {
        guard activeTouch === touch else { return }
        let windowLocation = touch.location(in: sourceWindow)
        let localLocation = sourceWindow.convert(windowLocation, to: self)
        let vector = normalizedVector(for: localLocation)
        let nextDirections = directions(for: vector)
        applyActiveDirections(nextDirections)
        onVectorChanged?(CGVector(dx: vector.dx, dy: vector.dy), nextDirections)
    }

    private func deactivateTouch(clearsOwner: Bool = true) {
        guard let touch = activeTouch else {
            deactivateAllDirections()
            return
        }
        activeTouch = nil
        if clearsOwner {
            Self.clearOwner(for: touch)
        }
        deactivateAllDirections()
    }

    private func deactivateAllDirections() {
        guard !activeDirections.isEmpty || activeTouch != nil else {
            onVectorChanged?(CGVector(dx: 0, dy: 0), [])
            return
        }

        let directions = activeDirections
        activeDirections.removeAll()
        for direction in directions {
            if let pressIdentifier = activeDirectionIdentifiers.removeValue(forKey: direction) {
                ControllerPressIdentifierAllocator.release(pressIdentifier)
                onDirectionEdge?(direction, false, pressIdentifier)
            }
        }
        onVectorChanged?(CGVector(dx: 0, dy: 0), [])
    }

    private func applyActiveDirections(_ nextDirections: Set<GamepadJoystickDirection>) {
        let endedDirections = activeDirections.subtracting(nextDirections)
        let beganDirections = nextDirections.subtracting(activeDirections)

        for direction in endedDirections {
            if let pressIdentifier = activeDirectionIdentifiers.removeValue(forKey: direction) {
                ControllerPressIdentifierAllocator.release(pressIdentifier)
                onDirectionEdge?(direction, false, pressIdentifier)
            }
        }

        for direction in beganDirections {
            let pressIdentifier = ControllerPressIdentifierAllocator.allocate()
            activeDirectionIdentifiers[direction] = pressIdentifier
            onDirectionEdge?(direction, true, pressIdentifier)
        }

        activeDirections = nextDirections
    }

    private func normalizedVector(for point: CGPoint) -> CGVector {
        let radiusX = max(bounds.width / 2, 1)
        let radiusY = max(bounds.height / 2, 1)
        let rawDX = (point.x - bounds.midX) / radiusX
        let rawDY = (point.y - bounds.midY) / radiusY
        let distance = hypot(rawDX, rawDY)
        guard distance > 0.001 else {
            return CGVector(dx: 0, dy: 0)
        }

        let clampedDistance = min(distance, 1)
        return CGVector(
            dx: (rawDX / distance) * clampedDistance,
            dy: (rawDY / distance) * clampedDistance
        )
    }

    private func directions(for vector: CGVector) -> Set<GamepadJoystickDirection> {
        var directions = Set<GamepadJoystickDirection>()
        if vector.dy <= -Self.directionThreshold { directions.insert(.up) }
        if vector.dy >= Self.directionThreshold { directions.insert(.down) }
        if vector.dx <= -Self.directionThreshold { directions.insert(.left) }
        if vector.dx >= Self.directionThreshold { directions.insert(.right) }
        return directions
    }

    private func containsTouch(at windowLocation: CGPoint, in sourceWindow: UIWindow) -> Bool {
        guard canReceiveRoutedTouch(in: sourceWindow) else { return false }
        let localLocation = sourceWindow.convert(windowLocation, to: self)
        return containsLocalPoint(localLocation)
    }

    private func containsLocalPoint(_ point: CGPoint) -> Bool {
        bounds.contains(point)
    }

    private func canReceiveRoutedTouch(in sourceWindow: UIWindow) -> Bool {
        window === sourceWindow
            && !isHidden
            && alpha > 0.01
            && isUserInteractionEnabled
            && bounds.width > 0
            && bounds.height > 0
    }

    private static func owner(for touch: UITouch) -> JoystickCaptureUIView? {
        let key = ObjectIdentifier(touch)
        guard let owner = touchOwners[key]?.view else {
            touchOwners[key] = nil
            return nil
        }
        return owner
    }

    private static func setOwner(_ owner: JoystickCaptureUIView, for touch: UITouch) {
        touchOwners[ObjectIdentifier(touch)] = WeakJoystickOwner(view: owner)
    }

    private static func clearOwner(for touch: UITouch) {
        touchOwners[ObjectIdentifier(touch)] = nil
    }

    private static func targetView(at windowLocation: CGPoint, in sourceWindow: UIWindow) -> JoystickCaptureUIView? {
        var bestView: JoystickCaptureUIView?
        var bestArea = CGFloat.greatestFiniteMagnitude
        let enumerator = registeredViews.objectEnumerator()

        while let view = enumerator.nextObject() as? JoystickCaptureUIView {
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
