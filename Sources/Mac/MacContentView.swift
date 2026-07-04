import SwiftUI
import CoreGraphics
import CoreImage.CIFilterBuiltins
import AppKit

struct MacContentView: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: MacSidebarSection? = .home
    @State private var advancedConfigExpanded = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(MacSidebarSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("PocketPad")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            selectedContent
                .navigationTitle((selectedSection ?? .home).title)
        }
        .geistScreenBackground()
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
        contentScroll {
            homeHero
            homeNextStepPanel

            if server.isPairingPending {
                pairingRequestPanel
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    activeKeypadPanel
                    homePairingPanel
                        .frame(width: 340)
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
                    activeKeypadPanel
                    homePairingPanel
                }
            }

            homeDiscoveryPanel
        }
    }

    private var homeHero: some View {
        homeHeroCopy
        .padding(Geist.Spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Geist.color(.gray100, scheme: colorScheme),
                            Geist.color(.background100, scheme: colorScheme),
                            Geist.color(.blue100, scheme: colorScheme).opacity(colorScheme == .dark ? 0.38 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var homeHeroCopy: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            MacStatusPill(
                title: homeStatusTitle,
                systemImage: homeStatusSystemImage,
                tone: homeStatusTone
            )

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Your iPhone, tuned for every Mac app.")
                    .geistTypography(.heading40)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("PocketPad turns a phone into a programmable shortcut keypad for games, editors, terminals, streams, and daily workflows.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s3) {
                    Button {
                        selectedSection = .gamepad
                    } label: {
                        Label("Edit Keypad", systemImage: "slider.horizontal.3")
                    }
                    .geistButtonStyle(.primary)

                    profileSwitcherMenu
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    Button {
                        selectedSection = .gamepad
                    } label: {
                        Label("Edit Keypad", systemImage: "slider.horizontal.3")
                    }
                    .geistButtonStyle(.primary)

                    profileSwitcherMenu
                }
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }


    private var homeNextStepPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
                SectionHeader(
                    title: homeNextStepTitle,
                    subtitle: homeNextStepSubtitle
                )

                Spacer(minLength: Geist.Spacing.s3)

                MacStatusPill(
                    title: homeReadinessSummary,
                    systemImage: homeReadinessSystemImage,
                    tone: homeReadinessTone
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    homeReadinessChecklist
                    Spacer(minLength: Geist.Spacing.s4)
                    homeNextStepActions
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    homeReadinessChecklist
                    homeNextStepActions
                }
            }
        }
        .geistPanel()
    }

    private var homeReadinessChecklist: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            readinessRow(
                title: "Accessibility",
                detail: server.accessibilityTrusted ? "Keyboard injection is allowed" : "Permission is required to send shortcuts",
                isComplete: server.accessibilityTrusted
            )
            readinessRow(
                title: "Mac helper",
                detail: server.isRunning ? "Listening on port \(server.port)" : "Server is stopped",
                isComplete: server.isRunning
            )
            readinessRow(
                title: "iPhone",
                detail: server.isClientConnected ? server.clientName : "Scan the QR code from PocketPad on iPhone",
                isComplete: server.isClientConnected
            )
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func readinessRow(title: String, detail: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s3) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isComplete ? Geist.color(.green900, scheme: colorScheme) : Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(detail)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var homeNextStepActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Geist.Spacing.s3) {
                homePrimaryNextStepButtons
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                homePrimaryNextStepButtons
            }
        }
    }

    @ViewBuilder
    private var homePrimaryNextStepButtons: some View {
        if !server.accessibilityTrusted {
            Button("Enable Accessibility") { server.promptForAccessibility() }
                .geistButtonStyle(.primary)
            Button("Open Settings") { server.openAccessibilitySettings() }
                .geistButtonStyle(.secondary)
            Button("Refresh") { server.refreshAccessibilityStatus() }
                .geistButtonStyle(.tertiary)
        } else if !server.isRunning {
            Button("Start Server") { server.start() }
                .geistButtonStyle(.primary)
            Button("Server Settings") { selectedSection = .settings }
                .geistButtonStyle(.secondary)
        } else if server.isClientConnected {
            Button {
                selectedSection = .gamepad
            } label: {
                Label("Customize Active Keypad", systemImage: "slider.horizontal.3")
            }
            .geistButtonStyle(.primary)
            Button("Release All Keys") { server.releaseAll(reason: "Home next step release all") }
                .geistButtonStyle(.secondary)
        } else {
            Button("Copy Pairing Code") { copyToPasteboard(server.pairingCode) }
                .geistButtonStyle(.primary)
            Button("Restart Server") { server.restart() }
                .geistButtonStyle(.secondary)
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
            customization: activeGamepadProfile?.customization ?? server.gamepadCustomization,
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
                Text("\(activeProfileControlCount) controls • \(server.gamepadProfiles.count) saved setups")
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
                homeMetricRow(
                    title: "Last event",
                    value: server.lastReceivedEvent,
                    systemImage: "waveform.path.ecg"
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

    @ViewBuilder
    private var homeTestButtons: some View {
        TestKeyButton(button: .left)
        TestKeyButton(button: .jump)
        TestKeyButton(button: .attack)
        Button("Release All Keys") { server.releaseAll(reason: "Home quick test release all") }
            .geistButtonStyle(.error)
            .keyboardShortcut(.escape, modifiers: [.command])
    }

    private var homePairingPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: server.isClientConnected ? "Pair Another iPhone" : "Pair Your iPhone",
                subtitle: server.isClientConnected
                    ? "Need a different phone? Scan this code from PocketPad on iPhone."
                    : "Open PocketPad on your iPhone and scan this QR code to connect."
            )

            if server.isRunning {
                VStack(alignment: .center, spacing: Geist.Spacing.s3) {
                    QRCodeView(text: server.pairingPayload)
                        .frame(width: server.isClientConnected ? 132 : 168, height: server.isClientConnected ? 132 : 168)

                    Text("Tap Scan Mac QR Code in PocketPad on iPhone.")
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
        let customization = activeGamepadProfile?.customization ?? server.gamepadCustomization
        return customization.resolvedControls(
            in: CGSize(width: 874, height: 402),
            defaultLabelProvider: { button in server.recordedShortcutLabel(for: button) }
        ).count
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

    private var homeNextStepSubtitle: String {
        if !server.accessibilityTrusted {
            return "macOS blocks keyboard injection until PocketPad Mac is allowed in Privacy & Security → Accessibility."
        }
        if !server.isRunning {
            return "The helper needs to be running so your iPhone can discover and pair with this Mac."
        }
        if server.isClientConnected {
            return "Focus the Mac app you want to control, then use the active keypad from your iPhone."
        }
        return "Scan the pairing code below from PocketPad on iPhone. After the first pair, Smart Connect can reconnect automatically."
    }

    private var homeReadinessSummary: String {
        if server.accessibilityTrusted && server.isRunning && server.isClientConnected { return "3 of 3 Ready" }
        let readyCount = [server.accessibilityTrusted, server.isRunning, server.isClientConnected].filter { $0 }.count
        return "\(readyCount) of 3 Ready"
    }

    private var homeReadinessSystemImage: String {
        server.accessibilityTrusted && server.isRunning && server.isClientConnected ? "checkmark.seal.fill" : "list.bullet.clipboard"
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

        if let existingID = existingProfileID(for: template) {
            selectedProfileID = existingID
        } else {
            let profile = template.makeProfile()
            profiles.append(profile)
            selectedProfileID = profile.id
        }

        server.setGamepadProfileState(
            profiles: profiles,
            activeProfileID: selectedProfileID,
            defaultProfileID: server.defaultGamepadProfileID
        )
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

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
            defaultLabelProvider: { button in
                server.recordedShortcutLabel(for: button)
            },
            selectedKeyBindingContent: { button in
                AnyView(
                    MacGamepadSelectedKeyBindingInspector(button: button)
                        .environmentObject(server)
                )
            },
            connectedDeviceInfo: server.clientDeviceInfo
        )
        .geistScreenBackground()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("PocketPad Mac Helper")
                    .geistTypography(.heading40)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("iPhone keypad → WebSocket → CGEvent keyboard shortcuts")
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
                    Text("macOS requires Accessibility access before PocketPad can inject keyboard events.")
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
                Text("Keyboard injection is blocked. Open System Settings → Privacy & Security → Accessibility and enable PocketPad Mac.")
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
                    Text("\(server.pendingPairingClientName ?? "An iPhone") wants to pair with PocketPad Mac.")
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
                Text("Enter this code on PocketPad iPhone:")
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
                    text: "No local IPv4 address found. Enable Wi‑Fi and refresh the server.",
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
            Text("Tap Scan Mac QR Code in PocketPad on iPhone.")
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

            VStack(spacing: 0) {
                DiagnosticRow(title: "Last Heartbeat", value: lastHeartbeatText)
                DiagnosticRow(title: "Estimated Latency", value: server.estimatedLatencyMS.map { "\($0) ms" } ?? "—")
                DiagnosticRow(title: "Missing Input Frames", value: "\(server.missedButtonFrames)")
                DiagnosticRow(title: "Ignored Input Edges", value: "\(server.ignoredButtonEdges)")
                DiagnosticRow(title: "Recovered Input Edges", value: "\(server.recoveredButtonEdges)")
                DiagnosticRow(title: "Last Event", value: server.lastReceivedEvent)
                DiagnosticRow(title: "Pressed Controls", value: pressedButtonsText)
            }
            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
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

            HStack(spacing: Geist.Spacing.s3) {
                TestKeyButton(button: .left)
                TestKeyButton(button: .jump)
                TestKeyButton(button: .attack)
                Button("Release All Keys") { server.releaseAll(reason: "Manual release all") }
                    .geistButtonStyle(.error)
                    .keyboardShortcut(.escape, modifiers: [.command])
            }
        }
        .geistPanel()
    }

    private var lastHeartbeatText: String {
        guard let date = server.lastHeartbeat else { return "—" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private var pressedButtonsText: String {
        if server.pressedButtons.isEmpty { return "None" }
        return server.pressedButtons
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
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
        case .warning: Geist.color(.amber900, scheme: scheme)
        case .error: Geist.color(.red900, scheme: scheme)
        }
    }

    func background(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray100, scheme: scheme)
        case .success: Geist.color(.blue100, scheme: scheme)
        case .warning: Geist.color(.amber100, scheme: scheme)
        case .error: Geist.color(.red100, scheme: scheme)
        }
    }

    func border(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.grayAlpha400, scheme: scheme)
        case .success: Geist.color(.blue400, scheme: scheme)
        case .warning: Geist.color(.amber400, scheme: scheme)
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

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = max(proxy.size.height, 1)
            let scale = max(0.001, min(availableWidth / designSize.width, availableHeight / designSize.height))
            let displaySize = CGSize(width: designSize.width * scale, height: designSize.height * scale)
            let controls = customization.resolvedControls(in: designSize, defaultLabelProvider: defaultLabelProvider)
            let previewColorScheme = customization.resolvedColorScheme(system: colorScheme)

            ZStack {
                RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                    .fill(Geist.color(.gray1000, scheme: previewColorScheme))
                    .frame(width: displaySize.width + 24 * scale, height: displaySize.height + 24 * scale)
                    .shadow(color: Color.black.opacity(previewColorScheme == .dark ? 0.24 : 0.10), radius: 18 * scale, x: 0, y: 10 * scale)

                ZStack(alignment: .topLeading) {
                    GamepadFillShapeLayer(
                        shape: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous),
                        fillStyle: customization.keypadBackgroundFillStyle(scheme: previewColorScheme)
                    )

                    ForEach(controls) { control in
                        MacKeypadPreviewControl(
                            control: control,
                            customization: customization,
                            scale: scale
                        )
                        .environment(\.colorScheme, previewColorScheme)
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(x: control.center.x * scale, y: control.center.y * scale)
                    }
                }
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
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
                Circle()
                    .stroke(control.layoutCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme).opacity(0.58), lineWidth: max(1, 3 * scale))
                    .padding(max(3, 10 * scale))
                Circle()
                    .fill(control.layoutCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme).opacity(0.42))
                    .frame(width: max(8, 22 * scale), height: max(8, 22 * scale))
            }

            if customization.showsButtonLabels {
                Text(control.label)
                    .geistTypography(.label12)
                    .foregroundStyle(control.layoutCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .padding(.horizontal, max(2, 4 * scale))
            }
        }
        .frame(width: max(1, control.size.width * scale), height: max(1, control.size.height * scale))
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

private struct TestKeyButton: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    let button: GameButton
    @State private var isPressed = false

    var body: some View {
        Text("\(server.keyLabel(for: button))  \(button.displayName)")
            .geistTypography(.button14)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 124, height: 52)
            .background(buttonFill, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isPressed ? Geist.color(.grayAlpha600, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isPressed ? 2 : 1)
            )
            .foregroundStyle(isPressed ? Geist.color(.background100, scheme: colorScheme) : Geist.color(.gray1000, scheme: colorScheme))
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        server.sendTestDown(button)
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        server.sendTestUp(button)
                    }
            )
            .onDisappear {
                if isPressed {
                    isPressed = false
                    server.sendTestUp(button)
                }
            }
    }

    private var buttonFill: Color {
        isPressed ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.gray100, scheme: colorScheme)
    }
}

private struct MacGamepadSelectedKeyBindingInspector: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    let button: GameButton

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s2) {
                Text("Shortcut")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button("Default") {
                    server.resetKeyBinding(button)
                }
                .geistButtonStyle(.tertiary, size: .small)
                .disabled(server.isDefaultBinding(for: button))
            }

            MacKeyBindingRecorderField(button: button)

            Text("Click the field, press one or more keys, then pause. It saves automatically.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
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

private struct MacKeyBindingRecorderField: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme

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

        server.setKeyBinding(MacKeyBinding(strokes: strokesToSave), for: button)
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
