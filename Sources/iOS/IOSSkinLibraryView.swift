import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct IOSSkinLibraryView: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var pendingImport: IOSPendingSkinImport?
    @State private var operationError: String?
    @State private var shareItem: IOSSkinShareItem?
    @AppStorage("PocketPad.iOS.skinHitAreaDebug.v1") private var showsHitAreas = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Geist.Spacing.s6) {
                    currentKeypadSection
                    installedSection
                }
                .padding(Geist.Spacing.s4)
            }
            .geistScreenBackground()
            .navigationTitle("Skins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import Skin", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pocketPadSkinPackage, .zip],
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .sheet(item: $pendingImport) { pending in
            IOSSkinImportReviewSheet(
                pending: pending,
                previewCustomization: previewCustomization(for: pending.package),
                showsHitAreas: showsHitAreas,
                onCancel: { pendingImport = nil },
                onInstall: { apply in install(pending, appliesAfterInstall: apply) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareItem) { item in
            IOSSkinActivitySheet(items: [item.url])
        }
        .alert(
            "Skin Library",
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: {
            Text(operationError ?? "The skin operation could not be completed.")
        }
    }

    private var currentKeypadSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("Current Keypad")
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Skins change appearance only. Your controls, labels, Mac shortcuts, and controller mappings stay intact.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            IOSKeypadSkinPreview(
                customization: currentPreviewCustomization,
                showsHitAreas: showsHitAreas
            )
            .frame(height: 220)
            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))

            HStack {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text(client.selectedGamepadProfileName)
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text(currentSkinName)
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }
                Spacer()
            }

            Toggle(isOn: $showsHitAreas) {
                Label("Show Touch Targets", systemImage: "hand.tap")
            }
            .toggleStyle(.switch)
            .tint(Geist.color(.blue700, scheme: colorScheme))

            if client.selectedGamepadProfile?.skinReference != nil {
                Button {
                    client.detachSkinFromSelectedProfile(colorScheme: pocketPadColorScheme)
                } label: {
                    Label("Fork Current Appearance", systemImage: "square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .geistButtonStyle(.secondary)
            }
        }
        .padding(Geist.Spacing.s4)
        .geistPanel()
    }

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("Installed Skins")
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Available offline and synchronized with your paired Mac.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }

            if client.installedSkins.isEmpty {
                ContentUnavailableView(
                    "No Skins Installed",
                    systemImage: "paintpalette",
                    description: Text("Import a .pocketpad file from Files or the Share Sheet.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ForEach(client.installedSkins) { installed in
                    skinCard(installed)
                }
            }
        }
    }

    private func skinCard(_ installed: PocketPadInstalledSkin) -> some View {
        let package = client.skinPackage(for: installed.reference)
        let isApplied = client.selectedGamepadProfile?.skinReference == installed.reference
        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            if let package {
                IOSKeypadSkinPreview(
                    customization: previewCustomization(for: package),
                    showsHitAreas: showsHitAreas
                )
                .frame(height: 190)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text(installed.manifest.name)
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("by \(installed.manifest.author.name) · v\(installed.reference.version)")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }
                Spacer()
                if isApplied {
                    Label("Applied", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))
                        .accessibilityLabel("Applied")
                }
            }

            if !installed.manifest.summary.isEmpty {
                Text(installed.manifest.summary)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(installed.manifest.license, systemImage: "checkmark.seal")
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray800, scheme: colorScheme))

            HStack(spacing: Geist.Spacing.s2) {
                Button {
                    apply(installed.reference)
                } label: {
                    Label(isApplied ? "Applied" : "Apply", systemImage: isApplied ? "checkmark" : "paintbrush.fill")
                        .frame(maxWidth: .infinity)
                }
                .geistButtonStyle(isApplied ? .secondary : .primary)
                .disabled(isApplied || package == nil)

                Button {
                    share(installed.reference, manifest: installed.manifest)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .geistButtonStyle(.secondary)
                .disabled(package == nil)
            }

            if !installed.isBundled {
                Button(role: .destructive) {
                    do { try client.removeSkin(installed.reference) }
                    catch { operationError = error.localizedDescription }
                } label: {
                    Label("Remove Skin", systemImage: "trash")
                }
                .font(.footnote.weight(.medium))
            }
        }
        .padding(Geist.Spacing.s4)
        .geistPanel()
    }

    private var currentSkinName: String {
        guard let reference = client.selectedGamepadProfile?.skinReference else { return "Local appearance" }
        return client.installedSkins.first(where: { $0.reference == reference }).map {
            "\($0.manifest.name) · v\($0.reference.version)"
        } ?? "Missing skin package"
    }

    private var pocketPadColorScheme: PocketPadSkinColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    private var currentPreviewCustomization: GamepadCustomization {
        guard let profile = client.selectedGamepadProfile else { return client.gamepadCustomization }
        let orientation = profile.customization.deviceCanvas.editorDeviceFrame.orientation
        return profile.resolvedCustomization(
            for: orientation,
            colorScheme: pocketPadColorScheme,
            skinPackage: client.skinPackage(for: profile.skinReference)
        )
    }

    private func previewCustomization(for package: PocketPadSkinPackage) -> GamepadCustomization {
        let source = client.selectedGamepadProfile?.customization ?? client.gamepadCustomization
        let orientation = source.deviceCanvas.editorDeviceFrame.orientation
        return source.applying(
            skinPackage: package,
            orientation: orientation == .portrait ? .portrait : .landscape,
            colorScheme: pocketPadColorScheme,
            options: .replacingAppearance
        )
    }

    private func apply(_ reference: PocketPadSkinReference) {
        do {
            try client.applySkinToSelectedProfile(reference, colorScheme: pocketPadColorScheme)
            KeypadHapticPlayer.shared.play(.init(style: .medium, pattern: .single, intensity: 0.62))
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            pendingImport = try IOSPendingSkinImport.load(from: url)
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func install(_ pending: IOSPendingSkinImport, appliesAfterInstall: Bool) {
        do {
            let result = try client.installSkinPackage(data: pending.data, policy: .replaceSameVersion)
            pendingImport = nil
            if appliesAfterInstall {
                apply(result.reference)
            }
        } catch {
            pendingImport = nil
            operationError = error.localizedDescription
        }
    }

    private func share(_ reference: PocketPadSkinReference, manifest: PocketPadSkinManifest) {
        do {
            let data = try client.skinPackageData(for: reference)
            let filename = suggestedFilename(for: manifest)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            shareItem = IOSSkinShareItem(url: url)
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func suggestedFilename(for manifest: PocketPadSkinManifest) -> String {
        let base = manifest.name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(base.isEmpty ? "pocketpad-skin" : base)-\(manifest.version).pocketpad"
    }
}

struct IOSPendingSkinImport: Identifiable {
    let id = UUID()
    let data: Data
    let package: PocketPadSkinPackage
    let report: PocketPadSkinValidationReport

    static func load(from url: URL) throws -> IOSPendingSkinImport {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let package = try PocketPadSkinPackageCodec.decode(data)
        guard package.skin != nil else { throw PocketPadSkinStoreError.packageHasNoSkin }
        return IOSPendingSkinImport(
            data: data,
            package: package,
            report: PocketPadSkinPackageValidator.validate(package)
        )
    }
}

struct IOSSkinImportReviewSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let pending: IOSPendingSkinImport
    let previewCustomization: GamepadCustomization
    let showsHitAreas: Bool
    let onCancel: () -> Void
    let onInstall: (Bool) -> Void

    private var compatibility: PocketPadSkinCompatibilityEvaluation {
        let orientation: PocketPadSkinOrientation = previewCustomization.deviceCanvas.editorDeviceFrame.orientation == .portrait
            ? .portrait
            : .landscape
        return PocketPadSkinCompatibilityEvaluator.evaluate(
            pending.package.manifest.compatibility,
            customization: previewCustomization,
            orientation: orientation
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    IOSKeypadSkinPreview(
                        customization: previewCustomization,
                        showsHitAreas: showsHitAreas
                    )
                    .frame(height: 240)
                    .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                        Text(pending.package.manifest.name)
                            .geistTypography(.heading24)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        Text("by \(pending.package.manifest.author.name) · v\(pending.package.manifest.version)")
                            .geistTypography(.copy14)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        if !pending.package.manifest.summary.isEmpty {
                            Text(pending.package.manifest.summary)
                                .geistTypography(.copy13)
                                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        }
                        Label(pending.package.manifest.license, systemImage: "checkmark.seal")
                            .geistTypography(.label13)
                    }
                    .padding(Geist.Spacing.s4)
                    .geistPanel()

                    Label(
                        "Appearance only. This file cannot change Mac shortcuts, controller mappings, launch targets, geometry, labels, or native accessibility controls.",
                        systemImage: "checkmark.shield.fill"
                    )
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))
                    .padding(Geist.Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Geist.color(.blue100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

                    if compatibility.status != .compatible {
                        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                            Label(
                                compatibility.status == .incompatible ? "Artwork does not match this keypad" : "Exact layout could not be confirmed",
                                systemImage: "rectangle.on.rectangle.slash"
                            )
                            .geistTypography(.label13)
                            ForEach(Array(compatibility.issues.enumerated()), id: \.offset) { _, issue in
                                Text(issue.message)
                                    .geistTypography(.copy13)
                            }
                            Text("Semantic control materials remain safe to apply; template-aligned canvas artwork is hidden.")
                                .geistTypography(.copy13)
                        }
                        .foregroundStyle(Geist.color(.amber900, scheme: colorScheme))
                        .padding(Geist.Spacing.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Geist.color(.amber100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                    }

                    ForEach(pending.report.warnings) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .geistTypography(.label12)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    }

                    Button {
                        onInstall(true)
                    } label: {
                        Label("Install & Apply", systemImage: "paintbrush.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .geistButtonStyle(.primary, size: .large)
                    .disabled(!pending.report.isValid)

                    Button {
                        onInstall(false)
                    } label: {
                        Text("Install for Later")
                            .frame(maxWidth: .infinity)
                    }
                    .geistButtonStyle(.secondary, size: .large)
                    .disabled(!pending.report.isValid)
                }
                .padding(Geist.Spacing.s4)
            }
            .navigationTitle("Review Skin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

private struct IOSKeypadSkinPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let customization: GamepadCustomization
    let showsHitAreas: Bool

    private var designSize: CGSize {
        customization.deviceCanvas.editorDeviceFrame.screenRect.size
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0.001, min(
                max(proxy.size.width - 24, 1) / max(designSize.width, 1),
                max(proxy.size.height - 24, 1) / max(designSize.height, 1)
            ))
            let displaySize = CGSize(width: designSize.width * scale, height: designSize.height * scale)
            let controls = customization.resolvedControls(in: designSize)
            let previewScheme = customization.resolvedColorScheme(system: colorScheme)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.86))
                    .frame(width: displaySize.width + 12, height: displaySize.height + 12)

                ZStack(alignment: .topLeading) {
                    GamepadFillShapeLayer(
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        fillStyle: customization.keypadBackgroundFillStyle(scheme: previewScheme)
                    )
                    GamepadArtworkLayersView(layers: customization.artworkLayers, plane: .underlay)

                    if showsHitAreas {
                        ForEach(controls.filter { !$0.isDecoration }) { control in
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Geist.color(.blue700, scheme: previewScheme).opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Geist.color(.blue700, scheme: previewScheme), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                )
                                .frame(width: control.hitFrame.width, height: control.hitFrame.height)
                                .position(x: control.hitFrame.midX, y: control.hitFrame.midY)
                        }
                    }

                    ForEach(controls) { control in
                        GamepadRenderedControlFace(
                            control: control,
                            customization: customization,
                            state: .normal
                        )
                        .environment(\.colorScheme, previewScheme)
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                    }
                    GamepadArtworkLayersView(layers: customization.artworkLayers, plane: .overlay)
                }
                .frame(width: designSize.width, height: designSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keypad skin preview")
    }
}

private struct IOSSkinShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct IOSSkinActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
