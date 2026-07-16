import CoreGraphics
import Foundation

public enum GamepadSharedOperationError: LocalizedError, Equatable, Sendable {
    case unsupportedControl(String)
    case controlNotFound(String)
    case customControlLimitReached
    case specializedControlLimitReached(GamepadCustomControlKind)
    case insufficientControls(required: Int)
    case groupNotFound(String)
    case emptyGroupName

    public var errorDescription: String? {
        switch self {
        case .unsupportedControl(let id):
            return "Control cannot be used by this operation: \(id)"
        case .controlNotFound(let id):
            return "Control not found: \(id)"
        case .customControlLimitReached:
            return "Maximum custom element count reached"
        case .specializedControlLimitReached(let kind):
            return "Maximum \(kind.rawValue) count reached"
        case .insufficientControls(let required):
            return "Select at least \(required) controls"
        case .groupNotFound(let value):
            return "Group not found: \(value)"
        case .emptyGroupName:
            return "Group name cannot be empty"
        }
    }
}

public extension GamepadControlIdentity {
    /// Parses the stable IDs returned by `id`, plus the legacy unprefixed values
    /// accepted by saved design metadata.
    init?(stableID value: String) {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let prefixes: [(String, (String) -> GamepadControlIdentity?)] = [
            ("builtin.", { GameButton(rawValue: $0).map(GamepadControlIdentity.builtin) }),
            ("custom.", { UUID(uuidString: $0).map(GamepadControlIdentity.custom) }),
            ("system.", { GamepadSystemControl(rawValue: $0).map(GamepadControlIdentity.system) }),
            ("control_bar_item.", { GamepadControlBarItem(rawValue: $0).map(GamepadControlIdentity.controlBarItem) })
        ]
        for (prefix, makeIdentity) in prefixes where raw.lowercased().hasPrefix(prefix) {
            let suffix = String(raw.dropFirst(prefix.count))
            if let identity = makeIdentity(suffix) {
                self = identity
                return
            }
        }

        if let button = GameButton(rawValue: raw) {
            self = .builtin(button)
        } else if let id = UUID(uuidString: raw) {
            self = .custom(id)
        } else if let control = GamepadSystemControl(rawValue: raw) {
            self = .system(control)
        } else if let item = GamepadControlBarItem(rawValue: raw) {
            self = .controlBarItem(item)
        } else {
            return nil
        }
    }
}

public struct GamepadElementDuplicationResult: Equatable, Sendable {
    public var identityMap: [GamepadControlIdentity: GamepadControlIdentity]

    public init(identityMap: [GamepadControlIdentity: GamepadControlIdentity]) {
        self.identityMap = identityMap
    }

    public var duplicatedIdentities: [GamepadControlIdentity] {
        identityMap.values.sorted { $0.id < $1.id }
    }
}

public enum GamepadControlAlignment: String, CaseIterable, Sendable {
    case leftEdges = "left"
    case horizontalCenters = "horizontal-centers"
    case rightEdges = "right"
    case topEdges = "top"
    case verticalCenters = "vertical-centers"
    case bottomEdges = "bottom"
}

public enum GamepadControlDistribution: String, CaseIterable, Sendable {
    case horizontalCenters = "horizontal-centers"
    case verticalCenters = "vertical-centers"
    case horizontalSpacing = "horizontal-spacing"
    case verticalSpacing = "vertical-spacing"
}

public enum GamepadProfileLayoutVariant: String, CaseIterable, Sendable {
    case landscape
    case portrait

    var editorOrientation: GamepadEditorDeviceOrientation {
        switch self {
        case .landscape: .landscape
        case .portrait: .portrait
        }
    }
}

public struct GamepadLayerGroupDuplicationResult: Equatable, Sendable {
    public var group: GamepadLayerGroup
    public var elements: GamepadElementDuplicationResult

    public init(group: GamepadLayerGroup, elements: GamepadElementDuplicationResult) {
        self.group = group
        self.elements = elements
    }
}

public extension GamepadCustomization {
    /// Duplicates built-in or custom controls as new custom controls. Element-level
    /// output and part-output bindings are cloned with the visual/control settings.
    @discardableResult
    mutating func duplicateControls(
        _ identities: [GamepadControlIdentity],
        normalizedOffset: CGSize = CGSize(width: 0.025, height: 0.025),
        canvasSize: CGSize? = nil
    ) throws -> GamepadElementDuplicationResult {
        let source = normalized
        var seen = Set<GamepadControlIdentity>()
        let requested = identities.filter { seen.insert($0).inserted }
        guard !requested.isEmpty else {
            throw GamepadSharedOperationError.insufficientControls(required: 1)
        }

        var sourceButtons: [(GamepadControlIdentity, GamepadCustomButton, KeypadElement?)] = []
        for identity in requested {
            switch identity {
            case .builtin(let button):
                guard GameButton.builtInControls.contains(button) else {
                    throw GamepadSharedOperationError.controlNotFound(identity.id)
                }
                var layout = source.buttonCustomization(for: button)
                let effectiveCanvas = canvasSize ?? source.deviceCanvas.editorDeviceFrame.screenRect.size
                if let control = source.resolvedControls(in: effectiveCanvas).first(where: { $0.id == identity }) {
                    layout.centerX = control.normalizedCenter.x
                    layout.centerY = control.normalizedCenter.y
                } else {
                    layout.centerX = layout.centerX ?? 0.5
                    layout.centerY = layout.centerY ?? 0.5
                }
                sourceButtons.append((
                    identity,
                    GamepadCustomButton(
                        mappedButton: button,
                        label: source.visualLabel(for: button),
                        layout: layout,
                        controlKind: .button
                    ),
                    source.element(for: identity)
                ))
            case .custom(let id):
                guard let button = source.customButtons.first(where: { $0.id == id })?.normalized else {
                    throw GamepadSharedOperationError.controlNotFound(identity.id)
                }
                sourceButtons.append((identity, button, source.element(for: identity)))
            case .system, .controlBarItem:
                throw GamepadSharedOperationError.unsupportedControl(identity.id)
            }
        }

        try validateDuplicationCapacity(sourceButtons.map { $0.1.controlKind })

        var next = source
        var identityMap: [GamepadControlIdentity: GamepadControlIdentity] = [:]
        for (sourceIdentity, sourceButton, sourceElement) in sourceButtons {
            let newID = UUID()
            let newIdentity = GamepadControlIdentity.custom(newID)
            var duplicate = sourceButton
            duplicate.id = newID
            duplicate.layout.centerX = Self.offsetCoordinate(duplicate.layout.centerX ?? 0.5, by: normalizedOffset.width)
            duplicate.layout.centerY = Self.offsetCoordinate(duplicate.layout.centerY ?? 0.5, by: normalizedOffset.height)
            next.customButtons.append(duplicate)
            next.elements.append(
                KeypadElement(
                    id: newID,
                    label: duplicate.label,
                    kind: duplicate.controlKind,
                    layout: duplicate.layout,
                    builtInButton: nil,
                    legacySlot: sourceElement?.legacySlot ?? duplicate.mappedButton,
                    output: sourceElement?.output,
                    partOutputs: sourceElement?.partOutputs ?? [:],
                    joystickMapping: duplicate.joystickMapping,
                    joystickOutputSettings: duplicate.joystickOutputSettings,
                    triggerSettings: duplicate.triggerSettings,
                    trackpadSettings: duplicate.trackpadSettings
                )
            )
            identityMap[sourceIdentity] = newIdentity
        }

        var metadata = next.designMetadata ?? .empty
        var order = source.orderedControlIdentitiesForDesign
        for sourceIdentity in requested {
            guard let duplicateIdentity = identityMap[sourceIdentity] else { continue }
            let insertionIndex = (order.firstIndex(of: sourceIdentity) ?? (order.count - 1)) + 1
            order.insert(duplicateIdentity, at: min(max(0, insertionIndex), order.count))
            for index in metadata.groups.indices {
                guard let childIndex = metadata.groups[index].children.firstIndex(of: sourceIdentity) else { continue }
                metadata.groups[index].children.insert(duplicateIdentity, at: childIndex + 1)
            }
        }
        metadata.layerOrder = order
        next.designMetadata = metadata.normalized(availableControls: next.allControlIdentitiesForDesign)
        self = next.normalized
        return GamepadElementDuplicationResult(identityMap: identityMap)
    }

    @discardableResult
    mutating func alignControls(
        _ identities: Set<GamepadControlIdentity>,
        alignment: GamepadControlAlignment,
        in canvasSize: CGSize
    ) throws -> Bool {
        let controls = resolvedControls(in: canvasSize).filter {
            identities.contains($0.id) && !$0.isLocationLocked && Self.supportsPositionOperations($0.id)
        }
        guard controls.count >= 2 else {
            throw GamepadSharedOperationError.insufficientControls(required: 2)
        }

        let target: CGFloat
        switch alignment {
        case .leftEdges: target = controls.map(\.frame.minX).min() ?? 0
        case .horizontalCenters: target = (controls.map(\.frame.minX).min()! + controls.map(\.frame.maxX).max()!) / 2
        case .rightEdges: target = controls.map(\.frame.maxX).max() ?? canvasSize.width
        case .topEdges: target = controls.map(\.frame.minY).min() ?? 0
        case .verticalCenters: target = (controls.map(\.frame.minY).min()! + controls.map(\.frame.maxY).max()!) / 2
        case .bottomEdges: target = controls.map(\.frame.maxY).max() ?? canvasSize.height
        }

        var changed = false
        for control in controls {
            var center = control.center
            switch alignment {
            case .leftEdges: center.x += target - control.frame.minX
            case .horizontalCenters: center.x = target
            case .rightEdges: center.x += target - control.frame.maxX
            case .topEdges: center.y += target - control.frame.minY
            case .verticalCenters: center.y = target
            case .bottomEdges: center.y += target - control.frame.maxY
            }
            let position = GamepadLayoutResolver.normalizedPosition(for: center, visualSize: control.size, in: canvasSize)
            setPosition(position, for: control.id)
            changed = changed || abs(center.x - control.center.x) > 0.001 || abs(center.y - control.center.y) > 0.001
        }
        self = normalized
        return changed
    }

    @discardableResult
    mutating func distributeControls(
        _ identities: Set<GamepadControlIdentity>,
        distribution: GamepadControlDistribution,
        in canvasSize: CGSize
    ) throws -> Bool {
        var controls = resolvedControls(in: canvasSize).filter {
            identities.contains($0.id) && !$0.isLocationLocked && Self.supportsPositionOperations($0.id)
        }
        guard controls.count >= 3 else {
            throw GamepadSharedOperationError.insufficientControls(required: 3)
        }

        let horizontal = distribution == .horizontalCenters || distribution == .horizontalSpacing
        controls.sort {
            horizontal ? ($0.center.x < $1.center.x) : ($0.center.y < $1.center.y)
        }
        let first = controls[0]
        let last = controls[controls.count - 1]
        var changed = false

        if distribution == .horizontalCenters || distribution == .verticalCenters {
            let start = horizontal ? first.center.x : first.center.y
            let end = horizontal ? last.center.x : last.center.y
            let step = (end - start) / CGFloat(controls.count - 1)
            for (index, control) in controls.enumerated().dropFirst().dropLast() {
                var center = control.center
                if horizontal { center.x = start + CGFloat(index) * step }
                else { center.y = start + CGFloat(index) * step }
                let position = GamepadLayoutResolver.normalizedPosition(for: center, visualSize: control.size, in: canvasSize)
                setPosition(position, for: control.id)
                changed = changed || abs(center.x - control.center.x) > 0.001 || abs(center.y - control.center.y) > 0.001
            }
        } else {
            let totalDimension = controls.reduce(CGFloat.zero) { partial, control in
                partial + (horizontal ? control.frame.width : control.frame.height)
            }
            let span = horizontal ? (last.frame.maxX - first.frame.minX) : (last.frame.maxY - first.frame.minY)
            let spacing = (span - totalDimension) / CGFloat(controls.count - 1)
            var trailingEdge = horizontal ? first.frame.maxX : first.frame.maxY
            for control in controls.dropFirst().dropLast() {
                var center = control.center
                let dimension = horizontal ? control.frame.width : control.frame.height
                let coordinate = trailingEdge + spacing + dimension / 2
                if horizontal { center.x = coordinate }
                else { center.y = coordinate }
                trailingEdge = coordinate + dimension / 2
                let position = GamepadLayoutResolver.normalizedPosition(for: center, visualSize: control.size, in: canvasSize)
                setPosition(position, for: control.id)
                changed = changed || abs(center.x - control.center.x) > 0.001 || abs(center.y - control.center.y) > 0.001
            }
        }
        self = normalized
        return changed
    }

    @discardableResult
    mutating func renameLayerGroup(id: UUID, to name: String) throws -> GamepadLayerGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GamepadSharedOperationError.emptyGroupName }
        var metadata = designMetadata ?? .empty
        guard let index = metadata.groups.firstIndex(where: { $0.id == id }) else {
            throw GamepadSharedOperationError.groupNotFound(id.uuidString)
        }
        metadata.groups[index].name = String(trimmed.prefix(48))
        designMetadata = metadata.normalized(availableControls: allControlIdentitiesForDesign)
        guard let group = designMetadata?.groups.first(where: { $0.id == id }) else {
            throw GamepadSharedOperationError.groupNotFound(id.uuidString)
        }
        return group
    }

    @discardableResult
    mutating func duplicateLayerGroup(
        id: UUID,
        name: String? = nil,
        normalizedOffset: CGSize = CGSize(width: 0.025, height: 0.025),
        canvasSize: CGSize? = nil
    ) throws -> GamepadLayerGroupDuplicationResult {
        guard let sourceGroup = designMetadata?.normalized(availableControls: allControlIdentitiesForDesign)?.groups.first(where: { $0.id == id }) else {
            throw GamepadSharedOperationError.groupNotFound(id.uuidString)
        }
        let requestedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let requestedName, requestedName.isEmpty { throw GamepadSharedOperationError.emptyGroupName }
        let elements = try duplicateControls(sourceGroup.children, normalizedOffset: normalizedOffset, canvasSize: canvasSize)
        let duplicatedChildren = sourceGroup.children.compactMap { elements.identityMap[$0] }
        let duplicate = GamepadLayerGroup(
            name: requestedName ?? "\(sourceGroup.name) Copy",
            children: duplicatedChildren,
            isLocked: sourceGroup.isLocked,
            isHidden: sourceGroup.isHidden
        )
        var metadata = designMetadata ?? .empty
        let duplicatedSet = Set(duplicatedChildren)
        for index in metadata.groups.indices {
            metadata.groups[index].children.removeAll { duplicatedSet.contains($0) }
        }
        metadata.groups.removeAll { $0.children.isEmpty }
        metadata.groups.append(duplicate)
        designMetadata = metadata.normalized(availableControls: allControlIdentitiesForDesign)
        guard let normalizedGroup = designMetadata?.groups.first(where: { $0.id == duplicate.id }) else {
            throw GamepadSharedOperationError.groupNotFound(duplicate.id.uuidString)
        }
        return GamepadLayerGroupDuplicationResult(group: normalizedGroup, elements: elements)
    }

    /// Applies one deterministic repair emitted by `layoutQualityReport`.
    /// Locked controls are always treated as fixed obstacles.
    @discardableResult
    internal mutating func applyLayoutRepair(
        _ repair: GamepadLayoutSuggestedRepair,
        in canvasSize: CGSize
    ) -> Bool {
        switch repair.kind {
        case .separateExpandedHitTargets:
            return separateExpandedHitTargets(in: canvasSize)
        case .ergonomicAutoArrange:
            return ergonomicallyAutoArrange(in: canvasSize)
        }
    }

    /// Applies all currently suggested repairs in report order.
    @discardableResult
    internal mutating func applySuggestedLayoutRepairs(in canvasSize: CGSize) -> [GamepadLayoutRepairKind] {
        let repairs = layoutQualityReport(canvasSize: canvasSize).suggestedRepairs
        var applied: [GamepadLayoutRepairKind] = []
        for repair in repairs where applyLayoutRepair(repair, in: canvasSize) {
            applied.append(repair.kind)
        }
        return applied
    }

    /// Packs unlocked controls without changing their size or layer order. Runtime
    /// hit frames are visual frames expanded by 10pt on every side.
    @discardableResult
    mutating func separateExpandedHitTargets(in canvasSize: CGSize) -> Bool {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return false }
        let controls = resolvedControls(in: canvasSize).filter { !$0.isDecoration }
        let locked = controls.filter(\.isLocationLocked).sorted { $0.id.id < $1.id.id }
        let movable = controls.filter { !$0.isLocationLocked }.sorted { $0.id.id < $1.id.id }
        var occupied = locked.map(\.frame)
        var next = self
        var changed = false

        for control in movable {
            let candidate = Self.nearestSeparatedFrame(
                to: control.frame,
                avoiding: occupied,
                in: canvasSize
            )
            occupied.append(candidate)
            guard hypot(candidate.midX - control.center.x, candidate.midY - control.center.y) > 0.01 else { continue }
            let position = GamepadLayoutResolver.normalizedPosition(for: CGPoint(x: candidate.midX, y: candidate.midY), visualSize: control.size, in: canvasSize)
            next.setPosition(position, for: control.id)
            changed = true
        }

        guard changed else { return false }
        self = next.normalized
        return true
    }

    /// Places primary movement/actions in lower side thumb arcs for the current
    /// orientation, while leaving utilities, trackpads, joysticks, triggers, and
    /// locked controls untouched.
    @discardableResult
    mutating func ergonomicallyAutoArrange(in canvasSize: CGSize) -> Bool {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return false }
        let portrait = canvasSize.height > canvasSize.width
        let controls = resolvedControls(in: canvasSize).filter { !$0.isDecoration && !$0.isLocationLocked }
        let movement = controls.filter { GamepadLayoutErgonomicRole.role(for: $0) == .movement }.sorted(by: Self.ergonomicControlSort)
        let actions = controls.filter { GamepadLayoutErgonomicRole.role(for: $0) == .action }.sorted(by: Self.ergonomicControlSort)
        guard !movement.isEmpty || !actions.isEmpty else { return false }

        var next = self
        var changed = false
        let movementAnchor = CGPoint(x: canvasSize.width * (portrait ? 0.27 : 0.18), y: canvasSize.height * (portrait ? 0.76 : 0.68))
        let actionAnchor = CGPoint(x: canvasSize.width * (portrait ? 0.73 : 0.82), y: canvasSize.height * (portrait ? 0.76 : 0.68))
        changed = Self.placeErgonomicCluster(movement, anchor: movementAnchor, movementCluster: true, canvasSize: canvasSize, customization: &next) || changed
        changed = Self.placeErgonomicCluster(actions, anchor: actionAnchor, movementCluster: false, canvasSize: canvasSize, customization: &next) || changed
        if changed {
            self = next.normalized
        }
        let separated = separateExpandedHitTargets(in: canvasSize)
        return changed || separated
    }

    private static func nearestSeparatedFrame(
        to original: CGRect,
        avoiding obstacles: [CGRect],
        in canvasSize: CGSize
    ) -> CGRect {
        let gap = GamepadLayoutQualityReport.runtimeHitOutset * 2
        let canvas = CGRect(origin: .zero, size: canvasSize)
        func fits(_ frame: CGRect) -> Bool {
            guard canvas.contains(frame) else { return false }
            let expanded = frame.insetBy(dx: -GamepadLayoutQualityReport.runtimeHitOutset, dy: -GamepadLayoutQualityReport.runtimeHitOutset)
            return obstacles.allSatisfy { obstacle in
                let other = obstacle.insetBy(dx: -GamepadLayoutQualityReport.runtimeHitOutset, dy: -GamepadLayoutQualityReport.runtimeHitOutset)
                let intersection = expanded.intersection(other)
                return intersection.isNull || intersection.width <= 0.5 || intersection.height <= 0.5
            }
        }
        guard !fits(original) else { return original }

        var xValues: [CGFloat] = [original.minX, 0, canvasSize.width - original.width]
        var yValues: [CGFloat] = [original.minY, 0, canvasSize.height - original.height]
        for obstacle in obstacles {
            xValues.append(obstacle.minX - gap - original.width)
            xValues.append(obstacle.maxX + gap)
            yValues.append(obstacle.minY - gap - original.height)
            yValues.append(obstacle.maxY + gap)
        }
        xValues = Array(Set(xValues.filter { $0 >= 0 && $0 + original.width <= canvasSize.width }))
        yValues = Array(Set(yValues.filter { $0 >= 0 && $0 + original.height <= canvasSize.height }))

        let candidates = xValues.flatMap { x in yValues.map { y in CGRect(x: x, y: y, width: original.width, height: original.height) } }
            .filter(fits)
            .sorted { lhs, rhs in
                let lhsDistance = hypot(lhs.midX - original.midX, lhs.midY - original.midY)
                let rhsDistance = hypot(rhs.midX - original.midX, rhs.midY - original.midY)
                if abs(lhsDistance - rhsDistance) > 0.001 { return lhsDistance < rhsDistance }
                if abs(lhs.minY - rhs.minY) > 0.001 { return lhs.minY < rhs.minY }
                return lhs.minX < rhs.minX
            }
        return candidates.first ?? original
    }

    private static func ergonomicControlSort(_ lhs: GamepadResolvedControl, _ rhs: GamepadResolvedControl) -> Bool {
        let order: [GameButton: Int] = [
            .up: 0, .left: 1, .right: 2, .down: 3,
            .jump: 4, .attack: 5, .dash: 6, .focus: 7,
            .custom1: 8, .custom2: 9, .custom3: 10, .custom4: 11,
            .custom5: 12, .custom6: 13, .custom7: 14, .custom8: 15
        ]
        let lhsOrder = order[lhs.mappedButton] ?? 100
        let rhsOrder = order[rhs.mappedButton] ?? 100
        return lhsOrder == rhsOrder ? lhs.id.id < rhs.id.id : lhsOrder < rhsOrder
    }

    private static func placeErgonomicCluster(
        _ controls: [GamepadResolvedControl],
        anchor: CGPoint,
        movementCluster: Bool,
        canvasSize: CGSize,
        customization: inout GamepadCustomization
    ) -> Bool {
        guard !controls.isEmpty else { return false }
        let maxDimension = controls.map { max($0.size.width, $0.size.height) }.max() ?? 44
        let step = maxDimension + GamepadLayoutQualityReport.runtimeHitOutset * 2 + 2
        let pattern: [CGPoint] = movementCluster
            ? [CGPoint(x: 0, y: -1), CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)]
            : [CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: -1)]
        var changed = false
        for (index, control) in controls.enumerated() {
            let ring = index / pattern.count
            let base = pattern[index % pattern.count]
            let multiplier = CGFloat(ring + 1)
            let proposed = CGPoint(x: anchor.x + base.x * step * multiplier, y: anchor.y + base.y * step * multiplier)
            let position = GamepadLayoutResolver.normalizedPosition(for: proposed, visualSize: control.size, in: canvasSize)
            let resolvedCenter = CGPoint(x: position.x * canvasSize.width, y: position.y * canvasSize.height)
            if hypot(resolvedCenter.x - control.center.x, resolvedCenter.y - control.center.y) > 0.01 {
                customization.setPosition(position, for: control.id)
                changed = true
            }
        }
        return changed
    }

    private func validateDuplicationCapacity(_ kinds: [GamepadCustomControlKind]) throws {
        guard customButtons.count + kinds.count <= Self.maximumCustomButtons else {
            throw GamepadSharedOperationError.customControlLimitReached
        }
        let existingKinds = Dictionary(grouping: customButtons.map { $0.normalized.controlKind }, by: { $0 }).mapValues(\.count)
        let addedKinds = Dictionary(grouping: kinds, by: { $0 }).mapValues(\.count)
        let limits: [(GamepadCustomControlKind, Int)] = [
            (.joystick, Self.maximumJoysticks),
            (.trigger, Self.maximumTriggers),
            (.trackpad, Self.maximumTrackpads)
        ]
        for (kind, limit) in limits where (existingKinds[kind] ?? 0) + (addedKinds[kind] ?? 0) > limit {
            throw GamepadSharedOperationError.specializedControlLimitReached(kind)
        }
    }

    private static func offsetCoordinate(_ value: CGFloat, by offset: CGFloat) -> CGFloat {
        guard value.isFinite, offset.isFinite else { return value }
        return min(max(value + offset, 0), 1)
    }

    private static func supportsPositionOperations(_ identity: GamepadControlIdentity) -> Bool {
        switch identity {
        case .builtin, .custom, .system: true
        case .controlBarItem: false
        }
    }
}

public extension GamepadConfigurationProfile {
    /// Copies a complete orientation variant and rotates its control positions into
    /// the destination canvas. Source and destination variants remain independently saved.
    mutating func copyLayoutVariant(
        from sourceVariant: GamepadProfileLayoutVariant,
        to destinationVariant: GamepadProfileLayoutVariant,
        automaticallyArrange: Bool = true
    ) {
        let sourceOrientation = sourceVariant.editorOrientation
        let destinationOrientation = destinationVariant.editorOrientation
        let sourceExists = hasCustomizationVariant(for: sourceOrientation)
            || customization.deviceCanvas.editorDeviceFrame.orientation == sourceOrientation
        guard sourceExists else { return }
        let source = customization(for: sourceOrientation)
        var destination = source

        let sourceFrame = source.deviceCanvas.editorDeviceFrame
        let destinationFrame = GamepadEditorDeviceFrame(spec: sourceFrame.spec, orientation: destinationOrientation)
        destination.deviceCanvas = GamepadDeviceCanvas(frameID: destinationFrame.id)

        if automaticallyArrange, sourceOrientation != destinationOrientation {
            let controls = source.resolvedControls(in: sourceFrame.screenRect.size)
            for control in controls {
                let transformed = Self.transformedPosition(
                    control.normalizedCenter,
                    from: sourceVariant,
                    to: destinationVariant
                )
                destination.setPosition(transformed, for: control.id)
            }
            if var metadata = destination.designMetadata {
                metadata.guides = metadata.guides.map { guide in
                    var transformed = guide
                    transformed.orientation = guide.orientation == .horizontal ? .vertical : .horizontal
                    if sourceVariant == .landscape && destinationVariant == .portrait {
                        transformed.position = guide.orientation == .vertical ? guide.position : 1 - guide.position
                    } else {
                        transformed.position = guide.orientation == .horizontal ? guide.position : 1 - guide.position
                    }
                    return transformed
                }
                destination.designMetadata = metadata.normalized(availableControls: destination.allControlIdentitiesForDesign)
            }
            // The control bar hotspot remains at the top in both orientations.
            destination.topBarActivationRegion.centerX = 0.5
            destination.topBarActivationRegion.centerY = source.topBarActivationRegion.centerY
        }

        destination = destination.normalized
        switch sourceVariant {
        case .landscape:
            if landscapeCustomization == nil { landscapeCustomization = source }
        case .portrait:
            if portraitCustomization == nil { portraitCustomization = source }
        }
        switch destinationVariant {
        case .landscape: landscapeCustomization = destination
        case .portrait: portraitCustomization = destination
        }
        customization = destination
        updatedAt = Date.currentMilliseconds
    }

    private static func transformedPosition(
        _ position: CGPoint,
        from source: GamepadProfileLayoutVariant,
        to destination: GamepadProfileLayoutVariant
    ) -> CGPoint {
        guard source != destination else { return position }
        switch (source, destination) {
        case (.landscape, .portrait):
            return CGPoint(x: position.y, y: 1 - position.x)
        case (.portrait, .landscape):
            return CGPoint(x: 1 - position.y, y: position.x)
        default:
            return position
        }
    }
}
