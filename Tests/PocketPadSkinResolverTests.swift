import SwiftUI
import XCTest

final class PocketPadSkinResolverTests: XCTestCase {
    func testApplyingSkinPreservesGeometryBindingsAndLocalOverrides() throws {
        var customization = GamepadCustomization.defaultValue.normalized
        var jump = customization.buttonCustomization(for: .jump)
        jump.centerX = 0.73
        jump.centerY = 0.64
        jump.icon = .text("LOCAL")
        jump.hitInsets = GamepadHitInsets(top: 4, leading: 8, bottom: 12, trailing: 16)
        customization.setButtonCustomization(jump, for: .jump)
        customization = customization.normalized
        let jumpID = KeypadElement.builtInID(for: .jump)
        let jumpIndex = try XCTUnwrap(customization.elements.firstIndex { $0.id == jumpID })
        let binding = KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 49))
        customization.elements[jumpIndex].output = binding

        let package = makeSkinPackage()
        let resolved = customization.applying(
            skinPackage: package,
            orientation: .landscape,
            colorScheme: .dark
        )

        let resolvedJump = resolved.buttonCustomization(for: .jump)
        XCTAssertEqual(resolvedJump.centerX, 0.73)
        XCTAssertEqual(resolvedJump.centerY, 0.64)
        XCTAssertEqual(resolvedJump.icon, .text("LOCAL"))
        XCTAssertEqual(resolvedJump.styleID, "skin-primary")
        XCTAssertEqual(resolvedJump.hitInsets, GamepadHitInsets(top: 4, leading: 8, bottom: 12, trailing: 16))
        XCTAssertEqual(resolved.element(for: jumpID)?.output, binding)
        XCTAssertEqual(customization.buttonCustomization(for: .jump).styleID, nil, "The saved customization must remain untouched")
    }

    func testReplacingAppearanceUsesSkinInsteadOfLocalAppearance() {
        var customization = GamepadCustomization.defaultValue
        var jump = customization.buttonCustomization(for: .jump)
        jump.icon = .text("LOCAL")
        jump.fillColor = color("#FF0000")
        jump.centerX = 0.77
        customization.setButtonCustomization(jump, for: .jump)

        let resolved = customization.applying(
            skinPackage: makeSkinPackage(),
            orientation: .landscape,
            colorScheme: .dark,
            options: .replacingAppearance
        )

        let resolvedJump = resolved.buttonCustomization(for: .jump)
        XCTAssertEqual(resolvedJump.centerX, 0.77, "Skin replacement must not replace geometry")
        XCTAssertEqual(resolvedJump.styleID, "skin-primary")
        XCTAssertEqual(resolvedJump.icon?.source, .asset)
        XCTAssertNil(resolvedJump.fillColor)
    }

    func testExplicitVisualRoleOverridesInferredRole() throws {
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(mappedTo: .jump)
        let index = try XCTUnwrap(customization.customButtons.indices.last)
        customization.customButtons[index].visualRole = .utility
        let id = customization.customButtons[index].id

        let resolved = customization.applying(
            skinPackage: makeSkinPackage(),
            orientation: .portrait,
            colorScheme: .light,
            options: .replacingAppearance
        )

        XCTAssertEqual(resolved.customButtons.first { $0.id == id }?.layout.styleID, "skin-utility")
        XCTAssertEqual(resolved.elements.first { $0.id == id }?.visualRole, .utility)
    }

    func testExternalAssetReferencesMaterializeForBackgroundAndControlIcons() throws {
        let package = makeSkinPackage()
        let resolved = GamepadCustomization.defaultValue.applying(
            skinPackage: package,
            orientation: .portrait,
            colorScheme: .dark,
            options: .replacingAppearance
        )

        XCTAssertEqual(resolved.assetLibrary.asset(id: "skin-image")?.data, Data("skin-image".utf8))
        guard case .image(let image) = resolved.keypadBackgroundFillStyle(scheme: .dark) else {
            return XCTFail("Expected image-backed skin background")
        }
        XCTAssertEqual(image.assetID, "skin-image")
        XCTAssertEqual(image.data, Data("skin-image".utf8))
        XCTAssertEqual(resolved.buttonCustomization(for: .jump).icon?.value, "skin-image")
    }

    func testAsymmetricHitInsetsExpandIndependentlyFromVisualFrame() throws {
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(mappedTo: .jump)
        let index = try XCTUnwrap(customization.customButtons.indices.last)
        customization.customButtons[index].layout.centerX = 0.5
        customization.customButtons[index].layout.centerY = 0.5
        customization.customButtons[index].layout.widthScale = 1
        customization.customButtons[index].layout.heightScale = 1
        customization.customButtons[index].layout.hitInsets = GamepadHitInsets(
            top: 4,
            leading: 8,
            bottom: 12,
            trailing: 16
        )

        let control = try XCTUnwrap(
            customization.resolvedControls(in: CGSize(width: 800, height: 400))
                .first { $0.id == .custom(customization.customButtons[index].id) }
        )
        XCTAssertEqual(control.hitFrame.minX, control.frame.minX - 8, accuracy: 0.001)
        XCTAssertEqual(control.hitFrame.maxX, control.frame.maxX + 16, accuracy: 0.001)
        XCTAssertEqual(control.hitFrame.minY, control.frame.minY - 4, accuracy: 0.001)
        XCTAssertEqual(control.hitFrame.maxY, control.frame.maxY + 12, accuracy: 0.001)
        XCTAssertEqual(control.hitCenter.x, control.center.x + 4, accuracy: 0.001)
        XCTAssertEqual(control.hitCenter.y, control.center.y + 4, accuracy: 0.001)
        XCTAssertTrue(customization.usesFreeformLayout)
        XCTAssertEqual(GamepadLayoutQualityReport.runtimeHitFrame(for: control), control.hitFrame)
    }

    func testSchemeVariantJoystickKnobColorAppliesToCustomJoystick() throws {
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(mappedTo: .up)
        let index = try XCTUnwrap(customization.customButtons.indices.last)
        customization.customButtons[index].controlKind = .joystick
        customization.customButtons[index].visualRole = .joystick
        let id = customization.customButtons[index].id
        let style = GamepadStyleToken(
            id: "joystick-material",
            name: "Joystick",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(fillStyle: .solid(color("#111111")))
            )
        )
        let skin = PocketPadSkin(
            base: PocketPadSkinAppearance(
                roleRules: [
                    PocketPadSkinRoleRule(
                        role: .joystick,
                        appearance: PocketPadSkinControlAppearance(styleID: style.id)
                    )
                ],
                styleLibrary: GamepadStyleLibrary(styles: [style])
            ),
            variants: [
                PocketPadSkinVariant(
                    id: "light-knob",
                    colorScheme: .light,
                    appearance: PocketPadSkinAppearance(roleRules: [
                        PocketPadSkinRoleRule(
                            role: .joystick,
                            appearance: PocketPadSkinControlAppearance(joystickKnobColor: color("#224466"))
                        )
                    ])
                ),
                PocketPadSkinVariant(
                    id: "dark-knob",
                    colorScheme: .dark,
                    appearance: PocketPadSkinAppearance(roleRules: [
                        PocketPadSkinRoleRule(
                            role: .joystick,
                            appearance: PocketPadSkinControlAppearance(joystickKnobColor: color("#88AACC"))
                        )
                    ])
                )
            ]
        )
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.joystick-skin",
                version: "1.0.0",
                name: "Joystick Skin",
                author: PocketPadSkinAuthor(name: "Tests")
            ),
            skin: skin
        )

        let light = customization.applying(
            skinPackage: package,
            orientation: .landscape,
            colorScheme: .light,
            options: .replacingAppearance
        )
        let dark = customization.applying(
            skinPackage: package,
            orientation: .landscape,
            colorScheme: .dark,
            options: .replacingAppearance
        )

        XCTAssertEqual(light.customButtons.first { $0.id == id }?.layout.joystickKnobColor?.hexString, "#224466")
        XCTAssertEqual(dark.customButtons.first { $0.id == id }?.layout.joystickKnobColor?.hexString, "#88AACC")
        XCTAssertEqual(light.customButtons.first { $0.id == id }?.layout.styleID, style.id)
        XCTAssertEqual(dark.customButtons.first { $0.id == id }?.layout.styleID, style.id)
    }

    func testVisualRoleAndHitInsetsRoundTripBackwardCompatibly() throws {
        let button = GamepadCustomButton(
            mappedButton: .custom1,
            label: "Utility",
            layout: GamepadButtonCustomization(
                hitInsets: GamepadHitInsets(top: 1, leading: 2, bottom: 3, trailing: 4)
            ),
            visualRole: .utility
        )
        let data = try JSONEncoder().encode(button)
        let decoded = try JSONDecoder().decode(GamepadCustomButton.self, from: data)
        XCTAssertEqual(decoded.visualRole, .utility)
        XCTAssertEqual(decoded.layout.hitInsets, GamepadHitInsets(top: 1, leading: 2, bottom: 3, trailing: 4))

        let legacy = Data(#"{"mappedButton":"jump","label":"Legacy","layout":{},"controlKind":"button"}"#.utf8)
        let legacyDecoded = try JSONDecoder().decode(GamepadCustomButton.self, from: legacy)
        XCTAssertNil(legacyDecoded.visualRole)
        XCTAssertNil(legacyDecoded.layout.hitInsets)
    }

    private func makeSkinPackage() -> PocketPadSkinPackage {
        let primary = GamepadStyleToken(
            id: "skin-primary",
            name: "Skin Primary",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(fillStyle: .solid(color("#123456")))
            )
        )
        let utility = GamepadStyleToken(
            id: "skin-utility",
            name: "Skin Utility",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(fillStyle: .solid(color("#334455")))
            )
        )
        let skin = PocketPadSkin(
            base: PocketPadSkinAppearance(
                backgroundFillStyle: .image(GamepadImageFill(assetID: "skin-image")),
                accentStyle: .purple,
                showsButtonLabels: false,
                roleRules: [
                    PocketPadSkinRoleRule(
                        role: .primaryAction,
                        appearance: PocketPadSkinControlAppearance(
                            styleID: primary.id,
                            icon: GamepadControlIcon(
                                source: .asset,
                                value: "skin-image",
                                placement: .center,
                                renderingMode: .original
                            )
                        )
                    ),
                    PocketPadSkinRoleRule(
                        role: .utility,
                        appearance: PocketPadSkinControlAppearance(styleID: utility.id)
                    )
                ],
                styleLibrary: GamepadStyleLibrary(styles: [primary, utility])
            )
        )
        let data = Data("skin-image".utf8)
        return PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.resolver-skin",
                version: "1.0.0",
                name: "Resolver Skin",
                author: PocketPadSkinAuthor(name: "Tests"),
                assets: [
                    PocketPadSkinResourceDescriptor(
                        id: "skin-image",
                        path: "assets/skin-image.png",
                        contentType: "image/png",
                        role: .texture,
                        byteCount: data.count,
                        sha256: "not-needed-by-resolver"
                    )
                ]
            ),
            skin: skin,
            assets: ["skin-image": data]
        )
    }

    private func color(_ hex: String) -> GamepadRGBAColor {
        GamepadRGBAColor(hexString: hex) ?? .defaultValue
    }
}
