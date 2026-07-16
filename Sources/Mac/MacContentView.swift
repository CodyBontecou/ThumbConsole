import SwiftUI
import CoreGraphics
import CoreImage.CIFilterBuiltins
import AppKit
import UniformTypeIdentifiers
import Combine

struct MacContentView: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @AppStorage(ThumbConsoleMacIPC.onboardingCompletedDefaultsKey) private var hasCompletedOnboarding = false
    @State private var selectedSection: MacSidebarSection? = .gamepad
    @State private var advancedConfigExpanded = false
    @State private var isShowingOnboarding = false
    @State private var gamepadEditorUndoTarget = MacGamepadEditorUndoTarget()
    @State private var isExportingKeypadConfiguration = false
    @State private var keypadExportDocument = MacKeypadConfigurationJSONDocument()
    @State private var keypadExportFilename = ThumbConsoleKeypadConfigurationExport.suggestedFilename()
    @State private var keypadExportError: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(MacSidebarSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("ThumbConsole")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            selectedContent
                .navigationTitle((selectedSection ?? .home).title)
        }
        .geistScreenBackground()
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingOnboarding = true
                } label: {
                    Label("Setup Guide", systemImage: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingOnboarding) {
            MacOnboardingView(
                onOpenEditor: {
                    hasCompletedOnboarding = true
                    isShowingOnboarding = false
                    selectedSection = .gamepad
                },
                onComplete: {
                    hasCompletedOnboarding = true
                    isShowingOnboarding = false
                }
            )
            .environmentObject(server)
            .frame(minWidth: 740, idealWidth: 860, minHeight: 560, idealHeight: 640)
        }
        .fileExporter(
            isPresented: $isExportingKeypadConfiguration,
            document: keypadExportDocument,
            contentType: .json,
            defaultFilename: keypadExportFilename
        ) { result in
            if case .failure(let error) = result,
               (error as? CocoaError)?.code != .userCancelled {
                keypadExportError = error.localizedDescription
            }
        }
        .alert(
            "Couldn’t Export Keypad",
            isPresented: Binding(
                get: { keypadExportError != nil },
                set: { isPresented in
                    if !isPresented { keypadExportError = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) { keypadExportError = nil }
        } message: {
            Text(keypadExportError ?? "The keypad could not be exported.")
        }
        .onAppear {
            guard !hasCompletedOnboarding else { return }
            DispatchQueue.main.async {
                isShowingOnboarding = true
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection ?? .home {
        case .home:
            homePage
        case .gamepad:
            gamepadEditorPage
        case .settings:
            contentScroll {
                pageHeader(
                    title: "Settings",
                    subtitle: "Diagnostics and advanced configuration for the Mac keypad helper.",
                    systemImage: "gearshape.fill"
                )
                keypadAppearanceSettingsPanel
                debugPanel
                advancedConfigurationPanel
            }
        }
    }

    private var homePage: some View {
        GeometryReader { proxy in
            homePageContent(availableSize: proxy.size)
        }
        .geistScreenBackground()
    }

    private func homePageContent(availableSize: CGSize) -> some View {
        let pagePadding = homePagePadding(for: availableSize.width)
        let contentWidth = max(0, availableSize.width - pagePadding * 2)
        let contentHeight = max(0, availableSize.height - pagePadding * 2)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
                homeHero(availableSize: CGSize(width: contentWidth, height: contentHeight))
            }
            .padding(pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: availableSize.height, alignment: .topLeading)
        }
    }

    private func homePagePadding(for width: CGFloat) -> CGFloat {
        if width < 760 { return Geist.Spacing.s4 }
        if width < 1100 { return Geist.Spacing.s6 }
        return Geist.Spacing.s8
    }

    private func homeHero(availableSize: CGSize) -> some View {
        let innerWidth = max(0, availableSize.width - Geist.Spacing.s6 * 2)
        let usesWideLayout = innerWidth >= 820
        let connectionWidth = homeConnectionCardWidth(for: innerWidth)
        let previewWidth = usesWideLayout
            ? max(0, innerWidth - connectionWidth - Geist.Spacing.s6)
            : innerWidth
        let previewHeight = homePreviewHeight(
            for: previewWidth,
            availableHeight: availableSize.height,
            isWideLayout: usesWideLayout
        )

        return VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            homeHeroHeader

            if usesWideLayout {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    homeActiveKeypadSurface(previewHeight: previewHeight)
                        .layoutPriority(1)

                    homeConnectionSummaryCard
                        .frame(width: connectionWidth)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    homeConnectionSummaryCard
                        .frame(maxWidth: min(560, innerWidth), alignment: .leading)
                    homeActiveKeypadSurface(previewHeight: previewHeight)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Geist.Spacing.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous))
    }

    private func homeConnectionCardWidth(for innerWidth: CGFloat) -> CGFloat {
        min(420, max(340, innerWidth * 0.30))
    }

    private func homePreviewHeight(for previewWidth: CGFloat, availableHeight: CGFloat, isWideLayout: Bool) -> CGFloat {
        let aspectHeight = previewWidth / activeKeypadPreviewAspectRatio
        let roomyCap: CGFloat = isWideLayout ? 460 : 360
        let viewportCap = availableHeight > 0
            ? availableHeight * (isWideLayout ? 0.58 : 0.45)
            : roomyCap
        let maxHeight = max(240, min(roomyCap, viewportCap))
        let minHeight = min(isWideLayout ? 280 : 220, maxHeight)
        return min(max(aspectHeight, minHeight), maxHeight)
    }

    private var homeHeroHeader: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s4) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("ThumbConsole")
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Text("Use your iPhone as the active keypad for the focused Mac app.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Geist.Spacing.s4)

            MacStatusPill(
                title: homeStatusTitle,
                systemImage: homeStatusSystemImage,
                tone: homeStatusTone
            )
        }
    }

    private func homeActiveKeypadSurface(previewHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s3) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text(activeProfileName)
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("\(activeProfileControlCount) elements • \(server.gamepadProfiles.count) saved setups")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: Geist.Spacing.s3)

                if server.activeGamepadProfileID == server.defaultGamepadProfileID {
                    MacStatusPill(title: "Default", systemImage: "star.fill", tone: .warning)
                }
            }

            activeKeypadPreview
                .frame(height: previewHeight)
                .frame(maxWidth: .infinity)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                        .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s3) {
                    homeActiveKeypadActions
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    homeActiveKeypadActions
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    homeInlineMetric(
                        title: "iPhone",
                        value: server.isClientConnected ? server.clientName : "Not connected",
                        systemImage: server.isClientConnected ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3.slash"
                    )
                    homeInlineMetric(
                        title: "Appearance",
                        value: (activeGamepadProfile?.customization ?? server.gamepadCustomization).colorSchemePreference.displayName,
                        systemImage: "circle.lefthalf.filled"
                    )
                    MacLiveActivityInlineMetric(
                        activity: server.liveActivity,
                        title: "Last event",
                        systemImage: "waveform.path.ecg",
                        value: { $0.lastReceivedEvent }
                    )
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    homeInlineMetric(
                        title: "iPhone",
                        value: server.isClientConnected ? server.clientName : "Not connected",
                        systemImage: server.isClientConnected ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3.slash"
                    )
                    homeInlineMetric(
                        title: "Appearance",
                        value: (activeGamepadProfile?.customization ?? server.gamepadCustomization).colorSchemePreference.displayName,
                        systemImage: "circle.lefthalf.filled"
                    )
                    MacLiveActivityInlineMetric(
                        activity: server.liveActivity,
                        title: "Last event",
                        systemImage: "waveform.path.ecg",
                        value: { $0.lastReceivedEvent }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var homeActiveKeypadActions: some View {
        Button {
            selectedSection = .gamepad
        } label: {
            Label("Edit Keypad", systemImage: "slider.horizontal.3")
        }
        .geistButtonStyle(.primary)

        profileSwitcherMenu

        Button("Make Default") {
            server.setDefaultGamepadProfile(server.activeGamepadProfileID)
        }
        .geistButtonStyle(.secondary)
        .disabled(server.activeGamepadProfileID == server.defaultGamepadProfileID)
    }

    private func homeInlineMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: Geist.Spacing.s2) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(1)
                Text(value)
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: Geist.Spacing.s1)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var homeConnectionSummaryCard: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s2) {
                Text(homeNextStepTitle)
                    .geistTypography(.heading16)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .lineLimit(2)

                Spacer(minLength: Geist.Spacing.s2)

                Text(homeReadinessSummary)
                    .geistTypography(.label12)
                    .foregroundStyle(homeReadinessTone.foreground(scheme: colorScheme))
                    .padding(.horizontal, Geist.Spacing.s2)
                    .padding(.vertical, Geist.Spacing.s1)
                    .background(homeReadinessTone.background(scheme: colorScheme), in: Capsule())
                    .overlay(Capsule().stroke(homeReadinessTone.border(scheme: colorScheme), lineWidth: 1))
                    .fixedSize()
            }

            Text(homeCompactConnectionSubtitle)
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            homeReadinessSummaryRows

            if server.isPairingPending {
                homePendingPairingInline
            } else if server.accessibilityTrusted && server.isRunning && !server.isClientConnected {
                homePairingCodeInline
            } else {
                homeCompactConnectionActions
            }
        }
    }

    private var homeReadinessSummaryRows: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            homeReadinessRow(
                title: "Accessibility",
                value: server.accessibilityTrusted ? "Allowed" : "Needed",
                systemImage: "checkmark.shield.fill",
                isComplete: server.accessibilityTrusted
            )
            homeReadinessRow(
                title: "Mac helper",
                value: server.isRunning ? "Port \(server.port)" : "Stopped",
                systemImage: "macbook",
                isComplete: server.isRunning
            )
            homeReadinessRow(
                title: "iPhone",
                value: server.isClientConnected ? server.clientName : "Waiting",
                systemImage: server.isClientConnected ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3",
                isComplete: server.isClientConnected
            )
        }
    }

    private func homeReadinessRow(title: String, value: String, systemImage: String, isComplete: Bool) -> some View {
        HStack(spacing: Geist.Spacing.s3) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isComplete ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.gray800, scheme: colorScheme))
                .frame(width: 16)

            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .lineLimit(1)

            Spacer(minLength: Geist.Spacing.s2)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var homePairingCodeInline: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Geist.Spacing.s3) {
                QRCodeView(text: server.pairingPayload)
                    .frame(width: 104, height: 104)
                homePairingCodeContent
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                QRCodeView(text: server.pairingPayload)
                    .frame(width: 120, height: 120)
                homePairingCodeContent
            }
        }
    }

    private var homePairingCodeContent: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pairing code")
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Text(server.pairingCode)
                    .geistTypography(.heading20)
                    .monospacedDigit()
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .textSelection(.enabled)
            }

            Text("Scan from ThumbConsole on iPhone or enter the code manually.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            homeCompactConnectionActions
        }
    }

    private var homePendingPairingInline: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(spacing: Geist.Spacing.s2) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for \(server.pendingPairingClientName ?? "iPhone")")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button("Cancel") {
                    server.cancelPairing()
                }
                .geistButtonStyle(.tertiary, size: .small)
            }

            Text(server.pairingCode)
                .geistTypography(.heading24)
                .monospacedDigit()
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .textSelection(.enabled)
        }
        .padding(Geist.Spacing.s3)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha600, scheme: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var homeCompactConnectionActions: some View {
        if !server.accessibilityTrusted {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    Button("Enable") { server.promptForAccessibility() }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Settings") { server.openAccessibilitySettings() }
                        .geistButtonStyle(.secondary, size: .small)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Button("Enable") { server.promptForAccessibility() }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Settings") { server.openAccessibilitySettings() }
                        .geistButtonStyle(.secondary, size: .small)
                }
            }
        } else if !server.isRunning {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    Button("Start Server") { server.start() }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Settings") { selectedSection = .settings }
                        .geistButtonStyle(.secondary, size: .small)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Button("Start Server") { server.start() }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Settings") { selectedSection = .settings }
                        .geistButtonStyle(.secondary, size: .small)
                }
            }
        } else if server.isClientConnected {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    Button("Edit Keypad") { selectedSection = .gamepad }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Release") { server.releaseAll(reason: "Home compact connection release all") }
                        .geistButtonStyle(.secondary, size: .small)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Button("Edit Keypad") { selectedSection = .gamepad }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Release") { server.releaseAll(reason: "Home compact connection release all") }
                        .geistButtonStyle(.secondary, size: .small)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    Button("Copy Code") { copyToPasteboard(server.pairingCode) }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Restart") { server.restart() }
                        .geistButtonStyle(.secondary, size: .small)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Button("Copy Code") { copyToPasteboard(server.pairingCode) }
                        .geistButtonStyle(.primary, size: .small)
                    Button("Restart") { server.restart() }
                        .geistButtonStyle(.secondary, size: .small)
                }
            }
        }
    }


    private var activeKeypadPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
                SectionHeader(
                    title: "Active Keypad",
                    subtitle: "Preview the setup that will sync to your iPhone, switch profiles, or test a few shortcuts locally."
                )

                Spacer(minLength: Geist.Spacing.s3)

                if server.activeGamepadProfileID == server.defaultGamepadProfileID {
                    MacStatusPill(title: "Default", systemImage: "star.fill", tone: .warning)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    activeKeypadPreview
                        .frame(width: 440, height: 232)
                    activeKeypadDetails
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    activeKeypadPreview
                        .frame(maxWidth: .infinity)
                        .frame(height: 232)
                    activeKeypadDetails
                }
            }

            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                        Text("Quick test")
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        Text("Hold a button to send keyDown; release to send keyUp.")
                            .geistTypography(.copy13)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    }

                    Spacer(minLength: Geist.Spacing.s3)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Geist.Spacing.s3) {
                        homeTestButtons
                    }
                    VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                        homeTestButtons
                    }
                }
                .disabled(!server.accessibilityTrusted || !server.isRunning)
                .opacity((server.accessibilityTrusted && server.isRunning) ? 1 : 0.52)
            }
        }
        .geistPanel()
    }

    private var activeKeypadPreview: some View {
        MacKeypadMiniPreview(
            customization: activeGamepadProfile?.customization(for: .landscape) ?? server.gamepadCustomization,
            defaultLabelProvider: { button in
                server.recordedShortcutLabel(for: button)
            }
        )
    }

    private var activeKeypadDetails: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(activeProfileName)
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .lineLimit(2)
                Text("\(activeProfileControlCount) elements • \(server.gamepadProfiles.count) saved setups")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }

            VStack(spacing: Geist.Spacing.s2) {
                homeMetricRow(
                    title: "iPhone",
                    value: server.isClientConnected ? server.clientName : "Not connected",
                    systemImage: server.isClientConnected ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3.slash"
                )
                homeMetricRow(
                    title: "Default setup",
                    value: defaultProfileName,
                    systemImage: "star.fill"
                )
                homeMetricRow(
                    title: "Appearance",
                    value: (activeGamepadProfile?.customization ?? server.gamepadCustomization).colorSchemePreference.displayName,
                    systemImage: "circle.lefthalf.filled"
                )
                MacLiveActivityMetricRow(
                    activity: server.liveActivity,
                    title: "Last event",
                    systemImage: "waveform.path.ecg",
                    value: { $0.lastReceivedEvent }
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s3) {
                    Button {
                        selectedSection = .gamepad
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .geistButtonStyle(.primary)

                    profileSwitcherMenu

                    Button("Make Default") {
                        server.setDefaultGamepadProfile(server.activeGamepadProfileID)
                    }
                    .geistButtonStyle(.secondary)
                    .disabled(server.activeGamepadProfileID == server.defaultGamepadProfileID)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    Button {
                        selectedSection = .gamepad
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .geistButtonStyle(.primary)

                    profileSwitcherMenu

                    Button("Make Default") {
                        server.setDefaultGamepadProfile(server.activeGamepadProfileID)
                    }
                    .geistButtonStyle(.secondary)
                    .disabled(server.activeGamepadProfileID == server.defaultGamepadProfileID)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func homeMetricRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 18)
            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 92, alignment: .leading)
            Text(value)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Geist.Spacing.s1)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var homeTestButtons: some View {
        MacLocalInputTestConsole(compact: true)
            .environmentObject(server)
    }

    private var homePairingPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: server.isClientConnected ? "Pair Another iPhone" : "Pair Your iPhone",
                subtitle: server.isClientConnected
                    ? "Need a different phone? Scan this code from ThumbConsole on iPhone."
                    : "Open ThumbConsole on your iPhone and scan this QR code to connect."
            )

            if server.isRunning {
                VStack(alignment: .center, spacing: Geist.Spacing.s3) {
                    QRCodeView(text: server.pairingPayload)
                        .frame(width: server.isClientConnected ? 132 : 168, height: server.isClientConnected ? 132 : 168)

                    Text("Tap Scan Mac QR Code in ThumbConsole on iPhone.")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Geist.Spacing.s2) {
                        Text("Code")
                            .geistTypography(.label12)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        Text(server.pairingCode)
                            .geistTypography(.label13Mono)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, Geist.Spacing.s3)
                    .padding(.vertical, Geist.Spacing.s2)
                    .background(Geist.color(.gray100, scheme: colorScheme), in: Capsule())
                }
                .frame(maxWidth: .infinity)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Geist.Spacing.s3) {
                        Button("Copy Code") { copyToPasteboard(server.pairingCode) }
                            .geistButtonStyle(.secondary, size: .small)
                        Button("Server Settings") { selectedSection = .settings }
                            .geistButtonStyle(.tertiary, size: .small)
                    }

                    VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                        Button("Copy Code") { copyToPasteboard(server.pairingCode) }
                            .geistButtonStyle(.secondary, size: .small)
                        Button("Server Settings") { selectedSection = .settings }
                            .geistButtonStyle(.tertiary, size: .small)
                    }
                }
            } else {
                MessageRow(text: "The Mac helper server is stopped. Start it before pairing an iPhone.", tone: .warning)
                Button("Start Server") { server.start() }
                    .geistButtonStyle(.primary)
            }
        }
        .geistPanel()
    }

    private var homeDiscoveryPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Start With a Setup",
                subtitle: "Install a familiar controller template or jump into a workflow idea, then tune every label and shortcut in the Keypad editor."
            )

            LazyVGrid(columns: homeDiscoveryColumns, alignment: .leading, spacing: Geist.Spacing.s3) {
                ForEach(homeTemplateShortlist, id: \.id) { template in
                    templateCard(template)
                }
            }

            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            LazyVGrid(columns: homeDiscoveryColumns, alignment: .leading, spacing: Geist.Spacing.s3) {
                homeUseCaseCard(
                    title: "Terminal & tmux",
                    subtitle: "Prefix sequences, pane jumps, scripts, and shell helpers.",
                    systemImage: "terminal",
                    buttonTitle: "Edit Shortcuts"
                ) {
                    selectedSection = .gamepad
                }

                homeUseCaseCard(
                    title: "Cursor / VS Code",
                    subtitle: "Command palette, refactors, AI actions, and navigation.",
                    systemImage: "curlybraces.square",
                    buttonTitle: "Customize"
                ) {
                    selectedSection = .gamepad
                }

                homeUseCaseCard(
                    title: "Window Control",
                    subtitle: "Map your favorite tiling, Mission Control, and app-switching keys.",
                    systemImage: "rectangle.3.group",
                    buttonTitle: "Build Setup"
                ) {
                    selectedSection = .gamepad
                }

                homeUseCaseCard(
                    title: "Presentations & Media",
                    subtitle: "Slides, mute, play/pause, markers, and stream controls.",
                    systemImage: "play.rectangle.on.rectangle",
                    buttonTitle: "Create Layout"
                ) {
                    selectedSection = .gamepad
                }
            }
        }
        .geistPanel()
    }

    private var homeDiscoveryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: Geist.Spacing.s3, alignment: .top)]
    }

    private var homeTemplateShortlist: [GamepadControllerTemplate] {
        [.snes, .playStation, .xbox, .arcadeStick, .gameBoy, .nes]
    }

    private func templateCard(_ template: GamepadControllerTemplate) -> some View {
        let existingID = existingProfileID(for: template)
        let isSelected = existingID == server.activeGamepadProfileID
        let actionTitle = isSelected ? "Selected" : (existingID == nil ? "Install" : "Select")

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .top, spacing: Geist.Spacing.s3) {
                Image(systemName: template.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text(template.displayName)
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .lineLimit(1)
                    Text(template.description)
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Geist.Spacing.s1)

            Button(actionTitle) { installTemplate(template) }
                .geistButtonStyle(isSelected ? .tertiary : .secondary, size: .small)
                .disabled(isSelected)
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(isSelected ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isSelected ? 1.5 : 1)
        )
    }

    private func homeUseCaseCard(
        title: String,
        subtitle: String,
        systemImage: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 36, height: 36)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(subtitle)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Geist.Spacing.s1)

            Button(buttonTitle, action: action)
                .geistButtonStyle(.tertiary, size: .small)
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
        .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var profileSwitcherMenu: some View {
        Menu {
            ForEach(server.gamepadProfiles) { profile in
                Button {
                    server.selectGamepadProfile(profile.id)
                } label: {
                    Label(
                        profile.name,
                        systemImage: profile.id == server.activeGamepadProfileID ? "checkmark.circle.fill" : (profile.id == server.defaultGamepadProfileID ? "star.fill" : "rectangle.grid.2x2")
                    )
                }
            }

            Divider()

            Button {
                selectedSection = .gamepad
            } label: {
                Label("Manage Setups", systemImage: "slider.horizontal.3")
            }
        } label: {
            Label("Switch Profile", systemImage: "rectangle.grid.2x2")
        }
        .menuStyle(.button)
        .geistButtonStyle(.secondary)
    }

    private var activeGamepadProfile: GamepadConfigurationProfile? {
        server.gamepadProfiles.first { $0.id == server.activeGamepadProfileID } ?? server.gamepadProfiles.first
    }

    private var activeProfileName: String {
        activeGamepadProfile?.name ?? "Current Setup"
    }

    private var defaultProfileName: String {
        server.gamepadProfiles.first { $0.id == server.defaultGamepadProfileID }?.name ?? "None"
    }

    private var activeProfileControlCount: Int {
        let customization = activeGamepadProfile?.customization(for: .landscape) ?? server.gamepadCustomization
        return customization.resolvedControls(
            in: CGSize(width: 874, height: 402),
            defaultLabelProvider: { button in server.recordedShortcutLabel(for: button) }
        ).count
    }

    private var activeKeypadPreviewAspectRatio: CGFloat {
        let screenSize = (activeGamepadProfile?.customization(for: .landscape) ?? server.gamepadCustomization)
            .deviceCanvas.editorDeviceFrame.screenRect.size
        return max(1.35, screenSize.width / max(screenSize.height, 1))
    }

    private var homeStatusTitle: String {
        if !server.accessibilityTrusted { return "Accessibility Needed" }
        if server.isClientConnected { return "iPhone Connected" }
        if server.isPairingPending { return "Pairing in Progress" }
        if server.isRunning { return "Waiting for iPhone" }
        return "Server Offline"
    }

    private var homeStatusSystemImage: String {
        if !server.accessibilityTrusted { return "exclamationmark.triangle.fill" }
        if server.isClientConnected { return "iphone.gen3.radiowaves.left.and.right" }
        if server.isPairingPending { return "lock.fill" }
        if server.isRunning { return "dot.radiowaves.left.and.right" }
        return "xmark.circle.fill"
    }

    private var homeStatusTone: MacInterfaceTone {
        if !server.accessibilityTrusted { return .warning }
        if server.isClientConnected { return .success }
        if server.isRunning { return .warning }
        return .error
    }

    private var homeNextStepTitle: String {
        if !server.accessibilityTrusted { return "Enable Accessibility to send shortcuts" }
        if !server.isRunning { return "Start the Mac helper" }
        if server.isClientConnected { return "Ready to control your Mac" }
        return "Connect your iPhone"
    }

    private var homeCompactConnectionSubtitle: String {
        if !server.accessibilityTrusted {
            return "Allow ThumbConsole to send shortcuts from your phone."
        }
        if !server.isRunning {
            return "Start the helper before pairing an iPhone."
        }
        if server.isClientConnected {
            return "\(server.clientName) is ready to control the focused Mac app."
        }
        return "Copy the pairing code here or scan the QR card below."
    }

    private var homeReadinessSummary: String {
        if server.accessibilityTrusted && server.isRunning && server.isClientConnected { return "3 of 3 Ready" }
        let readyCount = [server.accessibilityTrusted, server.isRunning, server.isClientConnected].filter { $0 }.count
        return "\(readyCount) of 3 Ready"
    }

    private var homeReadinessTone: MacInterfaceTone {
        server.accessibilityTrusted && server.isRunning && server.isClientConnected ? .success : .warning
    }

    private func existingProfileID(for template: GamepadControllerTemplate) -> UUID? {
        server.gamepadProfiles.first { profile in
            profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(template.displayName) == .orderedSame
        }?.id
    }

    private func installTemplate(_ template: GamepadControllerTemplate) {
        var profiles = server.gamepadProfiles
        let selectedProfileID: UUID
        var seededBindings: [UUID: [GameButton: MacControlOutputBinding]] = [:]

        if let existingID = existingProfileID(for: template) {
            selectedProfileID = existingID
        } else {
            let profile = template.makeProfile()
            profiles.append(profile)
            selectedProfileID = profile.id
            if let recommendedBindings = template.recommendedMacOutputBindings {
                seededBindings[profile.id] = recommendedBindings
            }
        }

        server.setGamepadProfileState(
            profiles: profiles,
            activeProfileID: selectedProfileID,
            defaultProfileID: server.defaultGamepadProfileID,
            seededProfileOutputBindings: seededBindings
        )
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

#if DEBUG
    private func replayOnboardingFromDebugSettings() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: ThumbConsoleMacIPC.editorFirstKeypadOnboardingCompletedDefaultsKey)
        UserDefaults.standard.set(true, forKey: ThumbConsoleMacIPC.editorFirstKeypadOnboardingReplayRequestedDefaultsKey)
        UserDefaults.standard.synchronize()
        isShowingOnboarding = false
        DispatchQueue.main.async {
            isShowingOnboarding = true
        }
    }
#endif

    private func contentScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
                content()
            }
            .padding(Geist.Spacing.s8)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .geistScreenBackground()
    }


    private var gamepadEditorPage: some View {
        MacGamepadEditorLiveInputReader(activity: server.liveActivity) { pressedElementInputs in
            GamepadCustomizationEditor(
                customization: Binding(
                    get: { server.gamepadCustomization },
                    set: { server.setGamepadCustomization($0) }
                ),
                initialProfiles: server.gamepadProfiles,
                initialSelectedProfileID: server.activeGamepadProfileID,
                initialDefaultProfileID: server.defaultGamepadProfileID,
                onReset: { server.resetGamepadCustomization() },
                onProfilesChanged: { profiles, activeProfileID, defaultProfileID in
                    server.setGamepadProfileState(
                        profiles: profiles,
                        activeProfileID: activeProfileID,
                        defaultProfileID: defaultProfileID
                    )
                },
                onExportProfiles: { profiles, activeProfileID, defaultProfileID, exportingProfileID in
                    prepareKeypadExport(
                        profiles: profiles,
                        activeProfileID: activeProfileID,
                        defaultProfileID: defaultProfileID,
                        exportingProfileID: exportingProfileID
                    )
                },
                onImportProfiles: { data, sourceName, appendAsCopies in
                    let summary = try server.importKeypadConfiguration(
                        data: data,
                        sourceName: sourceName,
                        mode: appendAsCopies ? .appendAsCopies : .replaceMatching
                    )
                    return summary.message
                },
                onRegisterProfileUndoSnapshot: { actionName in
                    registerMacGamepadUndoSnapshot(
                        server.editorUndoSnapshot(),
                        undoManager: undoManager,
                        undoTarget: gamepadEditorUndoTarget,
                        server: server,
                        actionName: actionName
                    )
                },
                onLaunchProfileTarget: { profileID in
                    server.launchAttachedApplication(for: profileID, source: "mac")
                },
                defaultLabelProvider: { button in
                    server.recordedShortcutLabel(for: button)
                },
                profileOutputModeContent: {
                    AnyView(
                        MacGamepadOutputModeInspector()
                            .environmentObject(server)
                    )
                },
                selectedElementOutputContent: { input in
                    AnyView(
                        MacKeypadElementOutputInspector(input: input)
                            .environmentObject(server)
                    )
                },
                connectedDeviceInfo: server.clientDeviceInfo,
                externallyPressedElementInputs: pressedElementInputs,
                editorDeliveryStatusText: editorDeliveryStatusText,
                onTestElementInputChanged: { input, isPressed in
                    if isPressed {
                        server.sendTestDown(input)
                    } else {
                        server.sendTestUp(input)
                    }
                },
                onTestElementInputTap: { input, holdMilliseconds in
                    server.sendTestTap(input, holdMilliseconds: holdMilliseconds)
                }
            )
        }
        .geistScreenBackground()
    }

    private var editorDeliveryStatusText: String {
        switch server.editorDeliveryState {
        case .localSave:
            "Saved locally"
        case .sending:
            "Saved locally · Sending…"
        case .sent:
            "Saved locally · Sent to iPhone"
        case .offline:
            "Saved locally · iPhone offline"
        case .failure:
            "Saved locally · Send failed"
        }
    }

    private func prepareKeypadExport(
        profiles: [GamepadConfigurationProfile],
        activeProfileID: UUID,
        defaultProfileID: UUID,
        exportingProfileID: UUID?
    ) {
        do {
            let data = try server.keypadConfigurationExportData(
                profiles: profiles,
                activeProfileID: activeProfileID,
                defaultProfileID: defaultProfileID,
                exportingProfileID: exportingProfileID
            )
            keypadExportDocument = MacKeypadConfigurationJSONDocument(data: data)
            let exportedProfileName = exportingProfileID.flatMap { profileID in
                profiles.first(where: { $0.id == profileID })?.name
            }
            keypadExportFilename = ThumbConsoleKeypadConfigurationExport.suggestedFilename(
                activeProfileName: exportedProfileName
            )
            isExportingKeypadConfiguration = true
        } catch {
            keypadExportError = error.localizedDescription
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("ThumbConsole Mac Helper")
                    .geistTypography(.heading40)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("iPhone keypad → WebSocket → keyboard shortcuts or virtual controller")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }

            Spacer(minLength: Geist.Spacing.s4)
            statusBadge
        }
    }

    private var statusBadge: some View {
        MacStatusPill(
            title: server.statusText,
            systemImage: server.isClientConnected ? "iphone.gen3.radiowaves.left.and.right" : (server.isPairingPending ? "lock.fill" : (server.isRunning ? "dot.radiowaves.left.and.right" : "xmark.circle.fill")),
            tone: server.isClientConnected ? .success : (server.isRunning ? .warning : .error)
        )
    }

    private func pageHeader(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s4) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 48, height: 48)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                        .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text(title)
                    .geistTypography(.heading40)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(subtitle)
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Text("Accessibility Permission")
                        .geistTypography(.heading20)
                    Text("macOS requires Accessibility access before ThumbConsole can inject keyboard events.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                MacStatusPill(
                    title: server.accessibilityTrusted ? "Permission Granted" : "Permission Required",
                    systemImage: server.accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                    tone: server.accessibilityTrusted ? .success : .warning
                )
            }

            if !server.accessibilityTrusted {
                Text("Keyboard injection is blocked. Open System Settings → Privacy & Security → Accessibility and enable ThumbConsole Mac.")
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Geist.Spacing.s3) {
                        accessibilityButtons
                    }
                    VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                        accessibilityButtons
                    }
                }
            }
        }
        .geistPanel()
    }

    @ViewBuilder
    private var accessibilityButtons: some View {
        Button("Request Accessibility Permission") { server.promptForAccessibility() }
            .geistButtonStyle(.primary)
        Button("Open Accessibility Settings") { server.openAccessibilitySettings() }
            .geistButtonStyle(.secondary)
        Button("Refresh Permission Status") { server.refreshAccessibilityStatus() }
            .geistButtonStyle(.tertiary)
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Connect From iPhone",
                subtitle: "Scan the QR code or enter one of these local WebSocket addresses in the iOS app."
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    connectionAddresses
                    Spacer(minLength: Geist.Spacing.s4)
                    qrCodeCard
                }
                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    connectionAddresses
                    qrCodeCard
                }
            }
        }
        .geistPanel()
    }

    private var pairingRequestPanel: some View {
        VStack(spacing: Geist.Spacing.s4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Text("Secure Pairing Request")
                        .geistTypography(.heading20)
                        .foregroundStyle(Color.white)
                    Text("\(server.pendingPairingClientName ?? "An iPhone") wants to pair with ThumbConsole Mac.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer()

                Button {
                    server.cancelPairing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel pairing")
            }

            VStack(spacing: Geist.Spacing.s3) {
                Text("Enter this code on ThumbConsole iPhone:")
                    .geistTypography(.label13)
                    .foregroundStyle(Color.white.opacity(0.72))

                Text(server.pairingCode)
                    .geistTypography(.heading32)
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .textSelection(.enabled)

                HStack(spacing: Geist.Spacing.s2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for iPhone to enter the code…")
                        .geistTypography(.copy13)
                }
                .foregroundStyle(Color.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Geist.Spacing.s4)
        }
        .padding(Geist.Spacing.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var connectionAddresses: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Local Addresses")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            if server.localURLs.isEmpty {
                MessageRow(
                    text: "No manual IPv4 address found. Smart Connect can still try nearby peer-to-peer; enable Wi‑Fi/Bluetooth for offline use.",
                    tone: .warning
                )
            } else {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    ForEach(server.localURLs, id: \.self) { url in
                        Text(url)
                            .geistTypography(.label14Mono)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .textSelection(.enabled)
                            .padding(.horizontal, Geist.Spacing.s3)
                            .frame(height: Geist.Spacing.s10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var qrCodeCard: some View {
        VStack(alignment: .center, spacing: Geist.Spacing.s3) {
            Text("Scan With iPhone")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            QRCodeView(text: server.pairingPayload)
                .frame(width: 152, height: 152)
            Text("Tap Scan Mac QR Code in ThumbConsole on iPhone.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(Geist.Spacing.s4)
        .frame(width: 200)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var serverInfoTiles: some View {
        HStack(spacing: Geist.Spacing.s3) {
            InfoTile(title: "Pairing Code", value: server.pairingCode, mono: true)
            InfoTile(title: "Client", value: server.clientName)
            InfoTile(title: "Port", value: "\(server.port)", mono: true)
        }
    }

    private var serverControls: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Button(server.isRunning ? "Restart Server" : "Start Server") {
                if server.isRunning {
                    server.restart()
                } else {
                    server.start()
                }
            }
            .geistButtonStyle(.primary)

            Button("Stop Server") { server.stop() }
                .geistButtonStyle(.secondary)
                .disabled(!server.isRunning)
        }
    }

    private var serverPortConfigurationContent: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            connectionAddresses

            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Geist.Spacing.s4) {
                    serverInfoTiles
                    Spacer()
                    serverControls
                }
                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    serverInfoTiles
                    serverControls
                }
            }
        }
    }

    private var gamepadCustomizationPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "iPhone Keypad Appearance",
                subtitle: "Customize the keypad rendered on the iPhone. Changes sync live to a connected phone and are sent during pairing."
            )

            GamepadCustomizationEditor(
                customization: Binding(
                    get: { server.gamepadCustomization },
                    set: { server.setGamepadCustomization($0) }
                ),
                onReset: { server.resetGamepadCustomization() },
                onLaunchProfileTarget: { profileID in
                    server.launchAttachedApplication(for: profileID, source: "mac")
                },
                defaultLabelProvider: { button in
                    server.recordedShortcutLabel(for: button)
                },
                connectedDeviceInfo: server.clientDeviceInfo
            )
            .frame(maxWidth: 720, alignment: .leading)
        }
        .geistPanel()
    }

    private var keyBindingsPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
                SectionHeader(
                    title: "Keypad Shortcuts",
                    subtitle: "Record a Mac key, modifier combo, or prefix sequence for each iPhone button. Changes are saved automatically."
                )

                Spacer()

                Button("Reset Shortcuts") {
                    server.resetAllKeyBindings()
                }
                .geistButtonStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: Geist.Spacing.s3, verticalSpacing: Geist.Spacing.s2) {
                ForEach(GameButton.allCases) { button in
                    GridRow {
                        Text(button.displayName)
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .frame(width: 82, alignment: .leading)

                        MacKeyBindingRecorderField(button: button)
                            .frame(minWidth: 180, maxWidth: 260)

                        Button("Restore Default") {
                            server.resetKeyBinding(button)
                        }
                        .geistButtonStyle(.tertiary, size: .small)
                        .disabled(server.isDefaultBinding(for: button))
                    }
                }
            }
        }
        .geistPanel()
    }

    private var keypadAppearanceSettingsPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Keypad Appearance",
                subtitle: "Choose whether the synced iPhone keypad follows the device appearance or is always rendered in light or dark mode."
            )

            Picker("Keypad Appearance", selection: keypadColorSchemePreferenceBinding) {
                ForEach(GamepadColorSchemePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Text(server.gamepadCustomization.colorSchemePreference.description)
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .geistPanel()
    }

    private var keypadColorSchemePreferenceBinding: Binding<GamepadColorSchemePreference> {
        Binding(
            get: { server.gamepadCustomization.colorSchemePreference },
            set: { preference in
                var customization = server.gamepadCustomization
                customization.colorSchemePreference = preference
                server.setGamepadCustomization(customization)
            }
        )
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Input Diagnostics",
                subtitle: "Transport and keyboard-injection details for live testing."
            )

            MacInputDiagnosticsRows(activity: server.liveActivity)

#if DEBUG
            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                SectionHeader(
                    title: "Debug Tools",
                    subtitle: "Developer-only actions for replaying first-run flows."
                )

                Button {
                    replayOnboardingFromDebugSettings()
                } label: {
                    Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
                }
                .geistButtonStyle(.secondary)

                Text("Resets the Mac setup guide and first-keypad editor tour, then opens the setup guide from the beginning.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
#endif
        }
        .geistPanel()
    }

    private var advancedConfigurationPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            DisclosureGroup(isExpanded: $advancedConfigExpanded) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    Text("Current WebSocket addresses, active port, and server controls update live from the Mac helper.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    serverPortConfigurationContent
                }
                .padding(.top, Geist.Spacing.s3)
            } label: {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Text("Advanced Configuration")
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Manage listener addresses, port status, and the Mac helper server.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }
            }
            .tint(Geist.color(.gray1000, scheme: colorScheme))
        }
        .geistPanel()
    }

    private var testPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Local Shortcut Test",
                subtitle: "Hold a test control to emit keyDown; release it to emit keyUp. Use Release All Keys if anything sticks."
            )

            MacLocalInputTestConsole(compact: false)
                .environmentObject(server)
        }
        .geistPanel()
    }

}

private struct MacLiveActivityInlineMetric: View {
    @ObservedObject var activity: MacControllerLiveActivity
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let value: (MacControllerLiveActivity) -> String

    var body: some View {
        HStack(spacing: Geist.Spacing.s2) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(1)
                Text(value(activity))
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: Geist.Spacing.s1)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacLiveActivityMetricRow: View {
    @ObservedObject var activity: MacControllerLiveActivity
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let value: (MacControllerLiveActivity) -> String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 18)
            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 92, alignment: .leading)
            Text(value(activity))
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Geist.Spacing.s1)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacInputDiagnosticsRows: View {
    @ObservedObject var activity: MacControllerLiveActivity
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            DiagnosticRow(title: "Last Heartbeat", value: lastHeartbeatText)
            DiagnosticRow(title: "Round-trip Latency", value: activity.estimatedLatencyMS.map { "\($0) ms" } ?? "—")
            DiagnosticRow(title: "Missing Input Frames", value: "\(activity.missedButtonFrames)")
            DiagnosticRow(title: "Ignored Input Edges", value: "\(activity.ignoredButtonEdges)")
            DiagnosticRow(title: "Recovered Input Edges", value: "\(activity.recoveredButtonEdges)")
            DiagnosticRow(title: "Last Event", value: activity.lastReceivedEvent)
            DiagnosticRow(title: "Pressed Inputs", value: pressedButtonsText)
        }
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var lastHeartbeatText: String {
        guard let date = activity.lastHeartbeat else { return "—" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private var pressedButtonsText: String {
        if activity.pressedButtons.isEmpty { return "None" }
        return activity.pressedButtons
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
    }
}

private enum MacOnboardingStep: String, CaseIterable, Identifiable, Hashable {
    case welcome
    case permissions
    case connect
    case editor

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .permissions: "Permissions"
        case .connect: "Connect iPhone"
        case .editor: "Keypad Editor"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: "What ThumbConsole does"
        case .permissions: "Allow shortcuts and local discovery"
        case .connect: "Pair over local or nearby network"
        case .editor: "Build and sync your controls"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "macbook.and.iphone"
        case .permissions: "checkmark.shield.fill"
        case .connect: "qrcode.viewfinder"
        case .editor: "slider.horizontal.3"
        }
    }
}

private struct MacOnboardingView: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedStep: MacOnboardingStep = .welcome

    let onOpenEditor: () -> Void
    let onComplete: () -> Void

    private var steps: [MacOnboardingStep] { MacOnboardingStep.allCases }
    private var selectedIndex: Int { steps.firstIndex(of: selectedStep) ?? 0 }
    private var isFirstStep: Bool { selectedIndex == 0 }
    private var isLastStep: Bool { selectedIndex == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 228)

                Divider()
                    .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

                ScrollView(.vertical, showsIndicators: false) {
                    stepContent
                        .padding(Geist.Spacing.s8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            footer
        }
        .geistScreenBackground()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s4) {
            Image(systemName: selectedStep.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 48, height: 48)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                        .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("Set up ThumbConsole")
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Enable the Mac helper, pair your iPhone, then customize the keypad that syncs to the phone.")
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Geist.Spacing.s4)

            MacStatusPill(
                title: readinessSummary,
                systemImage: server.accessibilityTrusted && server.isRunning && server.isClientConnected ? "checkmark.circle.fill" : "list.bullet.clipboard.fill",
                tone: server.accessibilityTrusted && server.isRunning && server.isClientConnected ? .success : .warning
            )
        }
        .padding(Geist.Spacing.s6)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            ForEach(steps) { step in
                onboardingStepButton(step)
            }

            Spacer(minLength: Geist.Spacing.s4)

            MacOnboardingStatusRow(
                title: "Accessibility",
                subtitle: server.accessibilityTrusted ? "Allowed" : "Needs permission",
                systemImage: "checkmark.shield.fill",
                isComplete: server.accessibilityTrusted
            )
            MacOnboardingStatusRow(
                title: "Mac helper",
                subtitle: server.isRunning ? "Port \(server.port)" : "Not running",
                systemImage: "dot.radiowaves.left.and.right",
                isComplete: server.isRunning
            )
            MacOnboardingStatusRow(
                title: "iPhone",
                subtitle: server.isClientConnected ? server.clientName : "Waiting to pair",
                systemImage: "iphone.gen3",
                isComplete: server.isClientConnected
            )
        }
        .padding(Geist.Spacing.s4)
        .background(Geist.color(.background200, scheme: colorScheme))
    }

    private func onboardingStepButton(_ step: MacOnboardingStep) -> some View {
        let isSelected = step == selectedStep

        return Button {
            selectedStep = step
        } label: {
            HStack(spacing: Geist.Spacing.s3) {
                Image(systemName: step.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.gray900, scheme: colorScheme))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text(step.subtitle)
                        .geistTypography(.label12)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .lineLimit(2)
                }

                Spacer(minLength: Geist.Spacing.s2)
            }
            .padding(Geist.Spacing.s3)
            .background(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .fill(isSelected ? Geist.color(.background100, scheme: colorScheme) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isSelected ? Geist.color(.grayAlpha400, scheme: colorScheme) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch selectedStep {
        case .welcome:
            welcomeStep
        case .permissions:
            permissionsStep
        case .connect:
            connectStep
        case .editor:
            editorStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                Text("Your iPhone becomes a programmable Mac keypad.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text("ThumbConsole Mac receives button presses from the iPhone and turns them into keyboard shortcuts, pointer gestures, or virtual controller output for the focused Mac app.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s4) {
                    MacOnboardingFeatureCard(title: "Mac helper", subtitle: "Runs the secure pairing server and sends shortcuts into the app you focus.", systemImage: "macbook")
                    MacOnboardingFeatureCard(title: "iPhone keypad", subtitle: "Connects over Wi‑Fi or nearby peer-to-peer, shows your synced setup, and sends low-latency presses.", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    MacOnboardingFeatureCard(title: "Keypad editor", subtitle: "Create profiles, move controls, record shortcuts, and choose the matching iPhone canvas.", systemImage: "slider.horizontal.3")
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    MacOnboardingFeatureCard(title: "Mac helper", subtitle: "Runs the secure pairing server and sends shortcuts into the app you focus.", systemImage: "macbook")
                    MacOnboardingFeatureCard(title: "iPhone keypad", subtitle: "Connects over Wi‑Fi or nearby peer-to-peer, shows your synced setup, and sends low-latency presses.", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    MacOnboardingFeatureCard(title: "Keypad editor", subtitle: "Create profiles, move controls, record shortcuts, and choose the matching iPhone canvas.", systemImage: "slider.horizontal.3")
                }
            }

            MacOnboardingCallout(
                title: "Before you start",
                text: "Keep this Mac and your iPhone on the same Wi‑Fi network, or leave Wi‑Fi/Bluetooth enabled for nearby peer-to-peer. Open ThumbConsole on both devices and leave the Mac helper running while you use the keypad.",
                systemImage: "wifi"
            )
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Grant the permissions ThumbConsole needs.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("macOS controls both keyboard injection and local-network discovery. The Mac helper can run before permissions are complete, but shortcuts will not fire until Accessibility is allowed.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                MacOnboardingPermissionCard(
                    title: "Accessibility",
                    subtitle: server.accessibilityTrusted ? "ThumbConsole can send keyboard and pointer events." : "Open System Settings → Privacy & Security → Accessibility, then enable ThumbConsole Mac.",
                    systemImage: "checkmark.shield.fill",
                    isComplete: server.accessibilityTrusted
                )

                MacOnboardingPermissionCard(
                    title: "Local Network",
                    subtitle: "If macOS asks, allow ThumbConsole to find and advertise devices on your local network. This enables Smart Connect and QR pairing.",
                    systemImage: "network",
                    isComplete: server.isRunning
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s3) {
                    permissionButtons
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    permissionButtons
                }
            }
        }
    }

    @ViewBuilder
    private var permissionButtons: some View {
        Button("Request Accessibility Permission") { server.promptForAccessibility() }
            .geistButtonStyle(.primary)
        Button("Open Accessibility Settings") { server.openAccessibilitySettings() }
            .geistButtonStyle(.secondary)
        Button("Refresh Status") { server.refreshAccessibilityStatus() }
            .geistButtonStyle(.tertiary)
    }

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Connect the iPhone to this Mac.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Use Smart Connect first. If the iPhone does not find this Mac automatically, scan the QR code or enter a local address and the six-digit pairing code.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    pairingQRCodeCard
                    pairingDetailsCard
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    pairingQRCodeCard
                    pairingDetailsCard
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s3) {
                    connectionButtons
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    connectionButtons
                }
            }
        }
    }

    private var pairingQRCodeCard: some View {
        VStack(alignment: .center, spacing: Geist.Spacing.s3) {
            Text("Scan from iPhone")
                .geistTypography(.heading16)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            QRCodeView(text: server.pairingPayload)
                .frame(width: 188, height: 188)
                .opacity(server.isRunning ? 1 : 0.42)

            Text(server.isRunning ? "Open ThumbConsole on iPhone → Scan Mac QR Code." : "Start the helper before scanning.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Geist.Spacing.s4)
        .frame(width: 240)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var pairingDetailsCard: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Pairing code")
                        .geistTypography(.label12)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    Text(server.pairingCode)
                        .geistTypography(.heading32)
                        .monospacedDigit()
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .textSelection(.enabled)
                }

                Spacer(minLength: Geist.Spacing.s4)

                MacStatusPill(
                    title: server.isClientConnected ? "Connected" : (server.isPairingPending ? "Pairing" : "Ready"),
                    systemImage: server.isClientConnected ? "checkmark.circle.fill" : "key.fill",
                    tone: server.isClientConnected ? .success : .warning
                )
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Local addresses")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                if server.localURLs.isEmpty {
                    MacOnboardingCallout(
                        title: "No manual address found",
                        text: "Connect to Wi‑Fi for manual addresses, or use Smart Connect/QR with Wi‑Fi and Bluetooth enabled for nearby peer-to-peer.",
                        systemImage: "wifi.exclamationmark"
                    )
                } else {
                    ForEach(server.localURLs, id: \.self) { url in
                        Text(url)
                            .geistTypography(.label13Mono)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .textSelection(.enabled)
                            .padding(.horizontal, Geist.Spacing.s3)
                            .frame(height: Geist.Spacing.s8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var connectionButtons: some View {
        Button(server.isRunning ? "Restart Helper" : "Start Helper") {
            if server.isRunning {
                server.restart()
            } else {
                server.start()
            }
        }
        .geistButtonStyle(.primary)

        Button("Copy Pairing Code") { copyToPasteboard(server.pairingCode) }
            .geistButtonStyle(.secondary)

        Button("Copy First Address") {
            if let url = server.localURLs.first {
                copyToPasteboard(url)
            }
        }
        .geistButtonStyle(.tertiary)
        .disabled(server.localURLs.isEmpty)
    }

    private var editorStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Customize the keypad before or after pairing.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text("The Mac Keypad editor is where profiles, layout, colors, haptics, shortcuts, and output mode are saved. Changes sync to the connected iPhone automatically.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                MacOnboardingInstructionCard(step: "1", title: "Create your first setup", text: "The editor starts with a blank setup. Add controls from the canvas toolbar, or open the templates menu only when you want an emulator-style starting point.")
                MacOnboardingInstructionCard(step: "2", title: "Match your iPhone canvas", text: "Select the connected iPhone frame, then edit portrait and landscape variants so controls land where your thumbs expect.")
                MacOnboardingInstructionCard(step: "3", title: "Move and style controls", text: "Drag controls on the canvas, use layout tools to add joysticks or trackpads, and adjust fills, icons, haptics, layers, and groups in the inspector.")
                MacOnboardingInstructionCard(step: "4", title: "Record shortcuts", text: "Select a control, click the shortcut field, press the Mac shortcut or prefix sequence, then pause. The binding saves automatically.")
                MacOnboardingInstructionCard(step: "5", title: "Sync and test", text: "Focus the Mac app you want to control. The connected iPhone receives the current profile and can switch setups from its Keypad menu.")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s3) {
                    Button("Open Keypad Editor") { onOpenEditor() }
                        .geistButtonStyle(.primary)
                    Button("Finish Guide") { onComplete() }
                        .geistButtonStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    Button("Open Keypad Editor") { onOpenEditor() }
                        .geistButtonStyle(.primary)
                    Button("Finish Guide") { onComplete() }
                        .geistButtonStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Button("Skip Guide") { onComplete() }
                .geistButtonStyle(.tertiary)

            Spacer(minLength: Geist.Spacing.s4)

            Button("Back") { moveSelection(by: -1) }
                .geistButtonStyle(.secondary)
                .disabled(isFirstStep)

            Button(isLastStep ? "Finish" : "Next") {
                if isLastStep {
                    onComplete()
                } else {
                    moveSelection(by: 1)
                }
            }
            .geistButtonStyle(.primary)
        }
        .padding(Geist.Spacing.s4)
    }

    private var readinessSummary: String {
        let readyCount = [server.accessibilityTrusted, server.isRunning, server.isClientConnected].filter { $0 }.count
        return readyCount == 3 ? "Ready" : "\(readyCount) of 3 ready"
    }

    private func moveSelection(by offset: Int) {
        let nextIndex = min(max(selectedIndex + offset, 0), steps.count - 1)
        selectedStep = steps[nextIndex]
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

private struct MacOnboardingStatusRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let systemImage: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: Geist.Spacing.s2) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isComplete ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.gray800, scheme: colorScheme))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(subtitle)
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(1)
            }
        }
        .padding(Geist.Spacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacOnboardingFeatureCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 36, height: 36)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading16)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(subtitle)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacOnboardingPermissionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let systemImage: String
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s3) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isComplete ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading16)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(subtitle)
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Geist.Spacing.s3)

            MacStatusPill(
                title: isComplete ? "Ready" : "Action needed",
                systemImage: isComplete ? "checkmark" : "exclamationmark.triangle.fill",
                tone: isComplete ? .success : .warning
            )
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacOnboardingInstructionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s3) {
            Text(step)
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.background100, scheme: colorScheme))
                .frame(width: 28, height: 28)
                .background(Geist.color(.gray1000, scheme: colorScheme), in: Circle())

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading16)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(text)
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacOnboardingCallout: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(text)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.blue100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.blue400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private enum MacSidebarSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case gamepad
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .gamepad: "Keypad"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .gamepad: "keyboard.fill"
        case .settings: "gearshape.fill"
        }
    }
}

private enum MacInterfaceTone {
    case neutral
    case success
    case warning
    case error

    func foreground(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray900, scheme: scheme)
        case .success: Geist.color(.blue900, scheme: scheme)
        case .warning: Geist.color(.gray1000, scheme: scheme)
        case .error: Geist.color(.red900, scheme: scheme)
        }
    }

    func background(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray100, scheme: scheme)
        case .success: Geist.color(.blue100, scheme: scheme)
        case .warning: Geist.color(.gray100, scheme: scheme)
        case .error: Geist.color(.red100, scheme: scheme)
        }
    }

    func border(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.grayAlpha400, scheme: scheme)
        case .success: Geist.color(.blue400, scheme: scheme)
        case .warning: Geist.color(.grayAlpha600, scheme: scheme)
        case .error: Geist.color(.red400, scheme: scheme)
        }
    }
}

private struct MacStatusPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let tone: MacInterfaceTone

    var body: some View {
        Label(title, systemImage: systemImage)
            .geistTypography(.label13)
            .foregroundStyle(tone.foreground(scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)
            .background(tone.background(scheme: colorScheme), in: Capsule())
            .overlay(Capsule().stroke(tone.border(scheme: colorScheme), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MessageRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let tone: MacInterfaceTone

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .geistTypography(.copy13)
            .foregroundStyle(tone.foreground(scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.background(scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(tone.border(scheme: colorScheme), lineWidth: 1)
            )
    }
}

private struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            Text(title)
                .geistTypography(.heading20)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            Text(subtitle)
                .geistTypography(.copy14)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InfoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
            Text(title)
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            Text(value)
                .geistTypography(mono ? .label14Mono : .label14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .frame(height: 56, alignment: .center)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacKeypadMiniPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let customization: GamepadCustomization
    var defaultLabelProvider: ((GameButton) -> String?)? = nil

    private var designSize: CGSize {
        customization.deviceCanvas.editorDeviceFrame.screenRect.size
    }

    private let deviceChromePadding: CGFloat = 24
    private let minimumPreviewPadding: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = max(proxy.size.height, 1)
            let fittedWidth = max(availableWidth - minimumPreviewPadding * 2, 1)
            let fittedHeight = max(availableHeight - minimumPreviewPadding * 2, 1)
            let deviceFrameSize = CGSize(
                width: designSize.width + deviceChromePadding,
                height: designSize.height + deviceChromePadding
            )
            let scale = max(0.001, min(fittedWidth / deviceFrameSize.width, fittedHeight / deviceFrameSize.height))
            let displaySize = CGSize(width: designSize.width * scale, height: designSize.height * scale)
            let controls = customization.resolvedControls(in: designSize, defaultLabelProvider: defaultLabelProvider)
            let previewColorScheme = customization.resolvedColorScheme(system: colorScheme)

            ZStack {
                RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                    .fill(Geist.color(.gray1000, scheme: previewColorScheme))
                    .frame(width: displaySize.width + deviceChromePadding * scale, height: displaySize.height + deviceChromePadding * scale)
                    .shadow(color: Color.black.opacity(previewColorScheme == .dark ? 0.24 : 0.10), radius: 18 * scale, x: 0, y: 10 * scale)

                ZStack(alignment: .topLeading) {
                    GamepadFillShapeLayer(
                        shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                        fillStyle: customization.keypadBackgroundFillStyle(scheme: previewColorScheme)
                    )

                    ForEach(controls) { control in
                        GamepadRenderedControlFace(
                            control: control,
                            customization: customization,
                            state: .normal,
                            secondaryBindingText: defaultLabelProvider?(control.mappedButton)
                        )
                        .environment(\.colorScheme, previewColorScheme)
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                    }
                }
                .frame(width: designSize.width, height: designSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: displaySize.width, height: displaySize.height, alignment: .topLeading)
                .overlay(
                    RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                        .stroke(Geist.color(.grayAlpha400, scheme: previewColorScheme), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Active keypad preview")
    }
}

private struct MacKeypadPreviewControl: View {
    @Environment(\.colorScheme) private var colorScheme
    let control: GamepadResolvedControl
    let customization: GamepadCustomization
    let scale: CGFloat

    var body: some View {
        ZStack {
            controlShape

            if control.isJoystick {
                joystickFace
            } else if control.isTrackpad {
                trackpadFace
            } else if customization.showsButtonLabels {
                controlLabel
            }
        }
        .frame(width: visualSize.width, height: visualSize.height)
        .shadow(
            color: Color.black.opacity(Double(min(0.18, 0.05 + 0.04 * control.layoutCustomization.shadowStrength))),
            radius: max(0.5, 4 * scale * control.layoutCustomization.shadowStrength),
            x: 0,
            y: max(0.5, 2 * scale * control.layoutCustomization.shadowStrength)
        )
    }

    private var resolvedAccentStyle: GamepadAccentStyle {
        control.layoutCustomization.accentStyle ?? customization.accentStyle
    }

    private var resolvedCornerRadii: GamepadCornerRadii {
        control.layoutCustomization.resolvedCornerRadii(defaultRadius: control.shape.defaultEditableCornerRadius(in: control.size))
    }

    private var scaledRectangleCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: resolvedCornerRadii.topLeading * scale,
            bottomLeading: resolvedCornerRadii.bottomLeading * scale,
            bottomTrailing: resolvedCornerRadii.bottomTrailing * scale,
            topTrailing: resolvedCornerRadii.topTrailing * scale
        )
    }

    private var visualSize: CGSize {
        CGSize(width: max(1, control.size.width * scale), height: max(1, control.size.height * scale))
    }

    private var controlForeground: Color {
        control.layoutCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
    }

    private var controlLabel: some View {
        Text(control.label)
            .geistTypography(.label12)
            .foregroundStyle(controlForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .padding(.horizontal, max(2, 4 * scale))
    }

    private var joystickFace: some View {
        let knobFillColor = control.layoutCustomization.joystickKnobFill(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let knobStrokeColor = control.layoutCustomization.joystickKnobStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let isThumbstick = control.layoutCustomization.joystickVisualStyle == .thumbstick
        let knobRatio: CGFloat = isThumbstick ? 0.72 : 0.34

        return ZStack {
            if !isThumbstick {
                Circle()
                    .stroke(controlForeground.opacity(0.24), lineWidth: max(0.75, 1 * scale))
                    .frame(width: visualSize.width * 0.70, height: visualSize.height * 0.70)
            }
            Circle()
                .fill(knobFillColor)
                .overlay(Circle().stroke(knobStrokeColor, lineWidth: max(0.75, 1 * scale)))
                .frame(
                    width: min(visualSize.width, visualSize.height) * knobRatio,
                    height: min(visualSize.width, visualSize.height) * knobRatio
                )

            if customization.showsButtonLabels && !isThumbstick {
                controlLabel
                    .offset(y: visualSize.height * (isThumbstick ? 0.58 : 0.34))
            }
        }
    }

    private var trackpadFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(4, 10 * scale), style: .continuous)
                .stroke(controlForeground.opacity(0.24), lineWidth: max(1, 1.5 * scale))
                .padding(max(3, 8 * scale))
            Image(systemName: "cursorarrow")
                .font(.system(size: max(9, 18 * scale), weight: .semibold))
                .foregroundStyle(controlForeground.opacity(0.62))
                .offset(y: max(-4, -8 * scale))

            if customization.showsButtonLabels {
                controlLabel
                    .offset(y: max(6, 12 * scale))
            }
        }
    }

    @ViewBuilder
    private var controlShape: some View {
        let fill = control.layoutCustomization.buttonFill(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let stroke = control.layoutCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let lineWidth = max(0.75, 1 * scale)

        switch control.shape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            UnevenRoundedRectangle(cornerRadii: scaledRectangleCornerRadii, style: .continuous)
                .fill(fill)
                .overlay(UnevenRoundedRectangle(cornerRadii: scaledRectangleCornerRadii, style: .continuous).stroke(stroke, lineWidth: lineWidth))
        case .polygon:
            GamepadRegularPolygonButtonShape(sides: 3)
                .fill(fill)
                .overlay(GamepadRegularPolygonButtonShape(sides: 3).stroke(stroke, lineWidth: lineWidth))
        case .star:
            GamepadStarButtonShape(points: 5)
                .fill(fill)
                .overlay(GamepadStarButtonShape(points: 5).stroke(stroke, lineWidth: lineWidth))
        }
    }
}

private struct DiagnosticRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 180, alignment: .leading)
            Text(value)
                .geistTypography(.label13Mono)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .textSelection(.enabled)
            Spacer(minLength: Geist.Spacing.s2)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(height: 1)
        }
    }
}

private struct MacLocalInputTestConsole: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    let compact: Bool

    @State private var selectedButton: GameButton = .jump
    @State private var holdMilliseconds: Double = 120
    @State private var locallyHeldButtons: Set<GameButton> = []
    @State private var pendingTapButton: GameButton?
    @State private var pendingTapTask: Task<Void, Never>?

    var body: some View {
        Group {
            if compact {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Geist.Spacing.s2) {
                        buttonPicker
                            .frame(minWidth: 150)
                        actionButtons
                        releaseButton
                    }
                    VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                        buttonPicker
                        actionButtons
                        holdDurationControl
                        releaseButton
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    HStack(spacing: Geist.Spacing.s3) {
                        buttonPicker
                            .frame(minWidth: 220, maxWidth: 320)
                        actionButtons
                        releaseButton
                    }
                    holdDurationControl
                }
            }
        }
        .disabled(!server.accessibilityTrusted || !server.isRunning)
        .opacity((server.accessibilityTrusted && server.isRunning) ? 1 : 0.52)
        .onDisappear(perform: releaseLocallyHeldInputs)
        .onChange(of: selectedButton) { oldButton, _ in
            release(oldButton)
        }
    }

    private var buttonPicker: some View {
        Picker("Test input", selection: $selectedButton) {
            ForEach(GameButton.allCases) { button in
                Text("\(button.displayName) · \(server.keyLabel(for: button))")
                    .tag(button)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Input to test")
    }

    private var actionButtons: some View {
        HStack(spacing: Geist.Spacing.s2) {
            Button("Down") { press(selectedButton) }
                .geistButtonStyle(.secondary, size: .small)
                .disabled(locallyHeldButtons.contains(selectedButton))
            Button("Up") { release(selectedButton) }
                .geistButtonStyle(.secondary, size: .small)
                .disabled(!locallyHeldButtons.contains(selectedButton))
            Button("Tap") { tap(selectedButton) }
                .geistButtonStyle(.primary, size: .small)
        }
    }

    private var holdDurationControl: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Text("Tap hold")
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            Slider(value: $holdMilliseconds, in: 20...2_000, step: 10)
                .frame(maxWidth: 280)
            Text("\(Int(holdMilliseconds)) ms")
                .geistTypography(.label13Mono)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private var releaseButton: some View {
        Button("Release All") { releaseLocallyHeldInputs() }
            .geistButtonStyle(.error, size: .small)
            .keyboardShortcut(.escape, modifiers: [.command])
    }

    private func press(_ button: GameButton) {
        guard !locallyHeldButtons.contains(button) else { return }
        locallyHeldButtons.insert(button)
        server.sendTestDown(button)
    }

    private func release(_ button: GameButton, cancelsPendingTap: Bool = true) {
        if cancelsPendingTap, pendingTapButton == button {
            pendingTapTask?.cancel()
            pendingTapTask = nil
            pendingTapButton = nil
        }
        guard locallyHeldButtons.remove(button) != nil else { return }
        server.sendTestUp(button)
    }

    private func tap(_ button: GameButton) {
        pendingTapTask?.cancel()
        pendingTapTask = nil
        pendingTapButton = nil
        release(button)
        press(button)
        pendingTapButton = button
        let delay = UInt64(max(0, holdMilliseconds) * 1_000_000)
        pendingTapTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            release(button, cancelsPendingTap: false)
            pendingTapTask = nil
            pendingTapButton = nil
        }
    }

    private func releaseLocallyHeldInputs() {
        pendingTapTask?.cancel()
        pendingTapTask = nil
        pendingTapButton = nil
        for button in locallyHeldButtons {
            server.sendTestUp(button)
        }
        locallyHeldButtons.removeAll()
        server.releaseAll(reason: "Local input test release all")
    }
}

private final class MacGamepadEditorLiveInputModel: ObservableObject {
    @Published private(set) var pressedElementInputs: Set<KeypadElementInputID>
    private var cancellable: AnyCancellable?

    init(activity: MacControllerLiveActivity) {
        pressedElementInputs = activity.pressedElementInputs
        cancellable = activity.$pressedElementInputs
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inputs in
                self?.pressedElementInputs = inputs
            }
    }
}

private struct MacGamepadEditorLiveInputReader<Content: View>: View {
    @StateObject private var model: MacGamepadEditorLiveInputModel
    let content: (Set<KeypadElementInputID>) -> Content

    init(
        activity: MacControllerLiveActivity,
        @ViewBuilder content: @escaping (Set<KeypadElementInputID>) -> Content
    ) {
        _model = StateObject(wrappedValue: MacGamepadEditorLiveInputModel(activity: activity))
        self.content = content
    }

    var body: some View {
        content(model.pressedElementInputs)
    }
}

private final class MacGamepadEditorUndoTarget {}

private func registerMacGamepadUndoSnapshot(
    _ snapshot: MacControllerServer.EditorUndoSnapshot,
    undoManager: UndoManager?,
    undoTarget: MacGamepadEditorUndoTarget,
    server: MacControllerServer,
    actionName: String
) {
    guard let undoManager else { return }
    undoManager.registerUndo(withTarget: undoTarget) { _ in
        let redoSnapshot = server.editorUndoSnapshot()
        server.restoreEditorUndoSnapshot(snapshot, reason: actionName)
        registerMacGamepadUndoSnapshot(
            redoSnapshot,
            undoManager: undoManager,
            undoTarget: undoTarget,
            server: server,
            actionName: actionName
        )
    }
    undoManager.setActionName(actionName)
}

private func performUndoableMacGamepadChange(
    undoManager: UndoManager?,
    undoTarget: MacGamepadEditorUndoTarget,
    server: MacControllerServer,
    actionName: String,
    change: () -> Void
) {
    let snapshot = server.editorUndoSnapshot()
    change()
    if server.editorUndoSnapshot() != snapshot {
        registerMacGamepadUndoSnapshot(
            snapshot,
            undoManager: undoManager,
            undoTarget: undoTarget,
            server: server,
            actionName: actionName
        )
    }
}

private struct MacGamepadOutputModeInspector: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @State private var undoTarget = MacGamepadEditorUndoTarget()

    private var outputModeBinding: Binding<GamepadProfileOutputMode> {
        Binding(
            get: { server.activeGamepadOutputMode },
            set: { mode in
                performUndoableMacGamepadChange(
                    undoManager: undoManager,
                    undoTarget: undoTarget,
                    server: server,
                    actionName: "Change Output Mode"
                ) {
                    server.setOutputMode(mode)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            Picker("Output", selection: outputModeBinding) {
                ForEach(GamepadProfileOutputMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(server.activeGamepadOutputMode.description)
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MacKeypadElementOutputInspector: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @State private var undoTarget = MacGamepadEditorUndoTarget()
    let input: KeypadElementInputID

    private var gamepadButtonSelection: Binding<VirtualGamepadButton?> {
        Binding(
            get: { server.gamepadButtonBinding(for: input) },
            set: { gamepadButton in
                performUndoableMacGamepadChange(
                    undoManager: undoManager,
                    undoTarget: undoTarget,
                    server: server,
                    actionName: "Change Element Gamepad Output"
                ) {
                    server.setGamepadButtonBinding(gamepadButton, for: input)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s2) {
                Text("Shortcut")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button {
                    performUndoableMacGamepadChange(
                        undoManager: undoManager,
                        undoTarget: undoTarget,
                        server: server,
                        actionName: "Clear Element Output"
                    ) {
                        server.clearElementOutputBinding(for: input)
                    }
                } label: {
                    Label("Clear Shortcut", systemImage: "xmark.circle")
                        .labelStyle(.iconOnly)
                }
                .geistButtonStyle(.tertiary, size: .small)
                .disabled(server.directElementOutputBinding(for: input) == nil)
                .help("Clear shortcut")
            }

            MacElementKeyBindingRecorderField(input: input)

            HStack(spacing: Geist.Spacing.s3) {
                Text("Gamepad")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer(minLength: Geist.Spacing.s2)
                Picker("Gamepad output", selection: gamepadButtonSelection) {
                    Text("None").tag(nil as VirtualGamepadButton?)
                    ForEach(VirtualGamepadButton.allCases) { gamepadButton in
                        Text(gamepadButton.displayName).tag(Optional(gamepadButton))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            Text("Element outputs are saved directly and can mix keyboard and controller output.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("Virtual gamepad output appears as a system HID controller when the Mac app is signed with Apple’s HID Virtual Device entitlement; keyboard output continues to work without it.")
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray700, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MacGamepadSelectedKeyBindingInspector: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @State private var undoTarget = MacGamepadEditorUndoTarget()
    let button: GameButton

    private var gamepadButtonSelection: Binding<VirtualGamepadButton?> {
        Binding(
            get: { server.gamepadButtonBinding(for: button) },
            set: { gamepadButton in
                performUndoableMacGamepadChange(
                    undoManager: undoManager,
                    undoTarget: undoTarget,
                    server: server,
                    actionName: "Change Gamepad Output"
                ) {
                    server.setGamepadButtonBinding(gamepadButton, for: button)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s2) {
                Text("Shortcut")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button("Default") {
                    performUndoableMacGamepadChange(
                        undoManager: undoManager,
                        undoTarget: undoTarget,
                        server: server,
                        actionName: "Reset Shortcut"
                    ) {
                        server.resetKeyBinding(button)
                    }
                }
                .geistButtonStyle(.tertiary, size: .small)
                .disabled(server.isDefaultBinding(for: button))
            }

            MacKeyBindingRecorderField(button: button)

            HStack(spacing: Geist.Spacing.s3) {
                Text("Gamepad")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer(minLength: Geist.Spacing.s2)
                Picker("Gamepad output", selection: gamepadButtonSelection) {
                    Text("None").tag(nil as VirtualGamepadButton?)
                    ForEach(VirtualGamepadButton.allCases) { gamepadButton in
                        Text(gamepadButton.displayName).tag(Optional(gamepadButton))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            Text("Per-button gamepad choices switch this setup to Custom output so it can mix keyboard shortcuts and controller buttons.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("Virtual gamepad output appears as a system HID controller when the Mac app is signed with Apple’s HID Virtual Device entitlement; keyboard output continues to work without it.")
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray700, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MacGamepadKeyBindingsInspector: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Keypad Shortcuts")
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Click a shortcut field and press the Mac key, modifier combo, or prefix sequence sent by each virtual button.")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("Reset All") {
                    server.resetAllKeyBindings()
                }
                .geistButtonStyle(.tertiary, size: .small)
            }

            VStack(spacing: Geist.Spacing.s2) {
                ForEach(GameButton.allCases) { button in
                    keyBindingRow(for: button)
                }
            }
        }
    }

    private func keyBindingRow(for button: GameButton) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s3) {
                Text(button.displayName)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .lineLimit(1)

                Spacer(minLength: Geist.Spacing.s2)

                Button("Default") {
                    server.resetKeyBinding(button)
                }
                .geistButtonStyle(.tertiary, size: .small)
                .disabled(server.isDefaultBinding(for: button))
            }

            MacKeyBindingRecorderField(button: button)
        }
        .padding(Geist.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacElementKeyBindingRecorderField: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @State private var undoTarget = MacGamepadEditorUndoTarget()

    let input: KeypadElementInputID
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var recordedStrokes: [MacKeyStroke] = []
    @State private var pendingModifierStroke: MacKeyStroke?
    @State private var commitWorkItem: DispatchWorkItem?

    private let sequenceCommitDelay: TimeInterval = 0.85

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Geist.Spacing.s2) {
                Text(fieldText)
                    .geistTypography(.label13Mono)
                    .foregroundStyle(fieldForeground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isRecording ? Geist.color(.red900, scheme: colorScheme) : Geist.color(.gray900, scheme: colorScheme))
            }
            .padding(.horizontal, Geist.Spacing.s3)
            .frame(height: Geist.Spacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(fieldBorder, lineWidth: isRecording ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Recording element shortcut" : "Click to record element shortcut")
        .accessibilityLabel("Element shortcut")
        .accessibilityValue(fieldText)
        .onDisappear {
            if isRecording {
                commitRecording()
            }
        }
    }

    private var fieldText: String {
        if isRecording {
            if !recordedStrokes.isEmpty {
                return MacKeyBinding(strokes: recordedStrokes).displayName
            }
            if let pendingModifierStroke {
                return pendingModifierStroke.displayName
            }
            return "Press shortcut…"
        }

        return server.elementOutputLabel(for: input)
    }

    private var isShowingPlaceholder: Bool {
        isRecording && recordedStrokes.isEmpty && pendingModifierStroke == nil
    }

    private var fieldForeground: Color {
        isShowingPlaceholder ? Geist.color(.gray900, scheme: colorScheme) : Geist.color(.gray1000, scheme: colorScheme)
    }

    private var fieldBackground: Color {
        isRecording ? Geist.color(.blue100, scheme: colorScheme) : Geist.color(.background100, scheme: colorScheme)
    }

    private var fieldBorder: Color {
        isRecording ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme)
    }

    private func handleTap() {
        if isRecording {
            commitRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard isRecording else { return event }

            switch event.type {
            case .keyDown:
                handleKeyDown(event)
            case .flagsChanged:
                handleFlagsChanged(event)
            default:
                break
            }

            return nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        pendingModifierStroke = nil
        recordedStrokes.append(MacKeyStroke(event: event))
        scheduleCommit(after: sequenceCommitDelay)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard recordedStrokes.isEmpty else { return }

        let keyCode = CGKeyCode(event.keyCode)
        guard let modifier = MacVirtualKey.keyModifier(for: keyCode) else { return }
        let activeModifiers = MacKeyModifiers(eventFlags: event.modifierFlags)

        if activeModifiers.contains(modifier) {
            pendingModifierStroke = MacKeyStroke(keyCode: keyCode)
        } else if let pendingModifierStroke, pendingModifierStroke.keyCode == keyCode {
            recordedStrokes = [pendingModifierStroke]
            self.pendingModifierStroke = nil
            scheduleCommit(after: 0.15)
        }
    }

    private func scheduleCommit(after delay: TimeInterval) {
        commitWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            commitRecording()
        }
        commitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func commitRecording() {
        let strokesToSave: [MacKeyStroke]
        if recordedStrokes.isEmpty, let pendingModifierStroke {
            strokesToSave = [pendingModifierStroke]
        } else {
            strokesToSave = recordedStrokes
        }

        guard !strokesToSave.isEmpty else {
            stopRecording()
            return
        }

        performUndoableMacGamepadChange(
            undoManager: undoManager,
            undoTarget: undoTarget,
            server: server,
            actionName: "Record Element Shortcut"
        ) {
            server.setElementKeyBinding(MacKeyBinding(strokes: strokesToSave), for: input)
        }
        stopRecording()
    }

    private func stopRecording() {
        commitWorkItem?.cancel()
        commitWorkItem = nil

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil

        isRecording = false
        recordedStrokes.removeAll(keepingCapacity: true)
        pendingModifierStroke = nil
    }
}

private struct MacKeyBindingRecorderField: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @State private var undoTarget = MacGamepadEditorUndoTarget()

    let button: GameButton
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var recordedStrokes: [MacKeyStroke] = []
    @State private var pendingModifierStroke: MacKeyStroke?
    @State private var commitWorkItem: DispatchWorkItem?

    private let sequenceCommitDelay: TimeInterval = 0.85

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Geist.Spacing.s2) {
                Text(fieldText)
                    .geistTypography(.label13Mono)
                    .foregroundStyle(fieldForeground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isRecording ? Geist.color(.red900, scheme: colorScheme) : Geist.color(.gray900, scheme: colorScheme))
            }
            .padding(.horizontal, Geist.Spacing.s3)
            .frame(height: Geist.Spacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(fieldBorder, lineWidth: isRecording ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Recording shortcut for \(button.displayName)" : "Click to record \(button.displayName)")
        .accessibilityLabel("Shortcut for \(button.displayName)")
        .accessibilityValue(fieldText)
        .onDisappear {
            if isRecording {
                commitRecording()
            }
        }
    }

    private var fieldText: String {
        if isRecording {
            if !recordedStrokes.isEmpty {
                return MacKeyBinding(strokes: recordedStrokes).displayName
            }
            if let pendingModifierStroke {
                return pendingModifierStroke.displayName
            }
            return "Press shortcut…"
        }

        return server.keyLabel(for: button)
    }

    private var isShowingPlaceholder: Bool {
        isRecording && recordedStrokes.isEmpty && pendingModifierStroke == nil
    }

    private var fieldForeground: Color {
        isShowingPlaceholder ? Geist.color(.gray900, scheme: colorScheme) : Geist.color(.gray1000, scheme: colorScheme)
    }

    private var fieldBackground: Color {
        isRecording ? Geist.color(.blue100, scheme: colorScheme) : Geist.color(.background100, scheme: colorScheme)
    }

    private var fieldBorder: Color {
        isRecording ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme)
    }

    private func handleTap() {
        if isRecording {
            commitRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard isRecording else { return event }

            switch event.type {
            case .keyDown:
                handleKeyDown(event)
            case .flagsChanged:
                handleFlagsChanged(event)
            default:
                break
            }

            return nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        pendingModifierStroke = nil
        recordedStrokes.append(MacKeyStroke(event: event))
        scheduleCommit(after: sequenceCommitDelay)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard recordedStrokes.isEmpty else { return }

        let keyCode = CGKeyCode(event.keyCode)
        guard let modifier = MacVirtualKey.keyModifier(for: keyCode) else { return }
        let activeModifiers = MacKeyModifiers(eventFlags: event.modifierFlags)

        if activeModifiers.contains(modifier) {
            pendingModifierStroke = MacKeyStroke(keyCode: keyCode)
        } else if let pendingModifierStroke, pendingModifierStroke.keyCode == keyCode {
            recordedStrokes = [pendingModifierStroke]
            self.pendingModifierStroke = nil
            scheduleCommit(after: 0.15)
        }
    }

    private func scheduleCommit(after delay: TimeInterval) {
        commitWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            commitRecording()
        }
        commitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func commitRecording() {
        let strokesToSave: [MacKeyStroke]
        if recordedStrokes.isEmpty, let pendingModifierStroke {
            strokesToSave = [pendingModifierStroke]
        } else {
            strokesToSave = recordedStrokes
        }

        guard !strokesToSave.isEmpty else {
            stopRecording()
            return
        }

        performUndoableMacGamepadChange(
            undoManager: undoManager,
            undoTarget: undoTarget,
            server: server,
            actionName: "Record Shortcut"
        ) {
            server.setKeyBinding(MacKeyBinding(strokes: strokesToSave), for: button)
        }
        stopRecording()
    }

    private func stopRecording() {
        commitWorkItem?.cancel()
        commitWorkItem = nil

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil

        isRecording = false
        recordedStrokes.removeAll(keepingCapacity: true)
        pendingModifierStroke = nil
    }
}

private struct QRCodeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Group {
            if let image = QRCodeRenderer.image(from: text) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 72))
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct MacKeypadConfigurationJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data("{}".utf8)) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum QRCodeRenderer {
    static func image(from text: String) -> NSImage? {
        guard !text.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
    }
}
