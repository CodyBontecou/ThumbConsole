import SwiftUI

struct GamepadArtworkLayersView: View {
    let layers: [ThumbleSkinArtworkLayer]
    let plane: ThumbleSkinArtworkPlane

    var body: some View {
        GeometryReader { proxy in
            let visible = layers.compactMap(\.normalized)
                .filter { $0.plane == plane && !$0.isHidden && $0.fillStyle != nil }
                .sorted { lhs, rhs in
                    if lhs.zIndex != rhs.zIndex { return lhs.zIndex < rhs.zIndex }
                    return lhs.id < rhs.id
                }
            ZStack {
                ForEach(visible) { layer in
                    let frame = layer.frame ?? ThumbleNormalizedRect(x: 0, y: 0, width: 1, height: 1)
                    if let fill = layer.fillStyle {
                        GamepadFillShapeLayer(shape: Rectangle(), fillStyle: fill)
                            .frame(
                                width: frame.width * proxy.size.width,
                                height: frame.height * proxy.size.height
                            )
                            .rotationEffect(.degrees(Double(layer.rotationDegrees)))
                            .opacity(Double(layer.opacity))
                            .blendMode(layer.blendMode.swiftUIBlendMode)
                            .position(
                                x: (frame.x + frame.width / 2) * proxy.size.width,
                                y: (frame.y + frame.height / 2) * proxy.size.height
                            )
                            .zIndex(Double(layer.zIndex))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension ThumbleSkinArtworkBlendMode {
    var swiftUIBlendMode: BlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .softLight: .softLight
        }
    }
}
