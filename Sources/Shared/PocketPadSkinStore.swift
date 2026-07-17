import Foundation
import SwiftUI

public struct PocketPadInstalledSkin: Equatable, Identifiable, Sendable {
    public var reference: PocketPadSkinReference
    public var manifest: PocketPadSkinManifest
    public var fileURL: URL
    public var installedAt: Date
    public var isBundled: Bool

    public init(
        reference: PocketPadSkinReference,
        manifest: PocketPadSkinManifest,
        fileURL: URL,
        installedAt: Date,
        isBundled: Bool = false
    ) {
        self.reference = reference
        self.manifest = manifest
        self.fileURL = fileURL
        self.installedAt = installedAt
        self.isBundled = isBundled
    }

    public var id: PocketPadSkinReference { reference }
}

public enum PocketPadSkinInstallPolicy: Sendable {
    /// Installs new versions, returns unchanged for byte-identical packages, and rejects replacement/downgrades.
    case newerOnly
    /// Replaces the exact version when its bytes differ, but still rejects a downgrade.
    case replaceSameVersion
    /// Allows installing any valid version and replacing an exact version.
    case allowDowngrade
}

public enum PocketPadSkinInstallResult: Equatable, Sendable {
    case installed(PocketPadSkinReference)
    case updated(PocketPadSkinReference, previousVersion: String)
    case replaced(PocketPadSkinReference)
    case unchanged(PocketPadSkinReference)

    public var reference: PocketPadSkinReference {
        switch self {
        case .installed(let reference), .replaced(let reference), .unchanged(let reference): reference
        case .updated(let reference, _): reference
        }
    }
}

public enum PocketPadSkinStoreError: LocalizedError, Equatable {
    case packageHasNoSkin
    case invalidIdentity
    case versionAlreadyInstalled(PocketPadSkinReference)
    case newerVersionInstalled(identifier: String, installedVersion: String)
    case skinNotInstalled(PocketPadSkinReference)
    case cannotCreateStore(String)
    case cannotWritePackage(String)
    case cannotRemovePackage(String)

    public var errorDescription: String? {
        switch self {
        case .packageHasNoSkin:
            "This package does not contain a skin."
        case .invalidIdentity:
            "The package does not have a valid skin identifier and semantic version."
        case .versionAlreadyInstalled(let reference):
            "\(reference.identifier) version \(reference.version) is already installed with different contents."
        case .newerVersionInstalled(let identifier, let installedVersion):
            "A newer version of \(identifier) (\(installedVersion)) is already installed."
        case .skinNotInstalled(let reference):
            "\(reference.identifier) version \(reference.version) is not installed."
        case .cannotCreateStore(let detail):
            "Could not create the PocketPad skin library: \(detail)"
        case .cannotWritePackage(let detail):
            "Could not install the PocketPad skin: \(detail)"
        case .cannotRemovePackage(let detail):
            "Could not remove the PocketPad skin: \(detail)"
        }
    }
}

/// A file-backed, process-safe-enough skin library. Every package remains an independently
/// shareable `.pocketpad` archive; the directory scan is the source of truth, so a partial index
/// can never hide an installed package.
public final class PocketPadSkinStore {
    public static let packageExtension = "pocketpad"

    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw PocketPadSkinStoreError.cannotCreateStore("Application Support is unavailable.")
            }
            self.rootURL = applicationSupport
                .appendingPathComponent("PocketPad", isDirectory: true)
                .appendingPathComponent("Skins", isDirectory: true)
        }
        do {
            try fileManager.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
        } catch {
            throw PocketPadSkinStoreError.cannotCreateStore(error.localizedDescription)
        }
    }

    public func installedSkins() throws -> [PocketPadInstalledSkin] {
        guard fileManager.fileExists(atPath: rootURL.path) else { return [] }
        let identifierURLs = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        var installed: [PocketPadInstalledSkin] = []
        for identifierURL in identifierURLs {
            let values = try? identifierURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            let packageURLs = (try? fileManager.contentsOfDirectory(
                at: identifierURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for packageURL in packageURLs where packageURL.pathExtension.lowercased() == Self.packageExtension {
                guard let data = try? Data(contentsOf: packageURL, options: [.mappedIfSafe]),
                      let package = try? PocketPadSkinPackageCodec.decode(data),
                      let reference = Self.reference(for: package)
                else { continue }
                let values = try? packageURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey])
                guard values?.isRegularFile != false, values?.isSymbolicLink != true else { continue }
                installed.append(PocketPadInstalledSkin(
                    reference: reference,
                    manifest: package.manifest,
                    fileURL: packageURL,
                    installedAt: values?.contentModificationDate ?? .distantPast,
                    isBundled: PocketPadBundledSkins.identifiers.contains(reference.identifier)
                ))
            }
        }
        return installed.sorted { lhs, rhs in
            if lhs.manifest.name != rhs.manifest.name {
                return lhs.manifest.name.localizedStandardCompare(rhs.manifest.name) == .orderedAscending
            }
            let left = PocketPadSemanticVersion(lhs.reference.version)
            let right = PocketPadSemanticVersion(rhs.reference.version)
            return (left ?? PocketPadSemanticVersion("0.0.0")!) > (right ?? PocketPadSemanticVersion("0.0.0")!)
        }
    }

    public func latestInstalledSkin(identifier: String) throws -> PocketPadInstalledSkin? {
        try installedSkins()
            .filter { $0.reference.identifier == identifier.lowercased() }
            .max { lhs, rhs in
                guard let left = PocketPadSemanticVersion(lhs.reference.version),
                      let right = PocketPadSemanticVersion(rhs.reference.version)
                else { return lhs.reference.version < rhs.reference.version }
                return left < right
            }
    }

    public func package(for reference: PocketPadSkinReference) throws -> PocketPadSkinPackage {
        try PocketPadSkinPackageCodec.decode(packageData(for: reference))
    }

    public func packageData(for reference: PocketPadSkinReference) throws -> Data {
        let url = try validatedPackageURL(for: reference)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PocketPadSkinStoreError.skinNotInstalled(reference)
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    @discardableResult
    public func install(
        data: Data,
        policy: PocketPadSkinInstallPolicy = .newerOnly
    ) throws -> PocketPadSkinInstallResult {
        let package = try PocketPadSkinPackageCodec.decode(data)
        guard package.skin != nil else { throw PocketPadSkinStoreError.packageHasNoSkin }
        guard let reference = Self.reference(for: package),
              let incomingVersion = PocketPadSemanticVersion(reference.version)
        else { throw PocketPadSkinStoreError.invalidIdentity }

        let installedForIdentifier = try installedSkins().filter {
            $0.reference.identifier == reference.identifier
        }
        let latest = installedForIdentifier.max { lhs, rhs in
            guard let left = PocketPadSemanticVersion(lhs.reference.version),
                  let right = PocketPadSemanticVersion(rhs.reference.version)
            else { return lhs.reference.version < rhs.reference.version }
            return left < right
        }
        let destination = try validatedPackageURL(for: reference)
        if fileManager.fileExists(atPath: destination.path) {
            let existingData = try Data(contentsOf: destination, options: [.mappedIfSafe])
            if existingData == data { return .unchanged(reference) }
            guard policy != .newerOnly else {
                throw PocketPadSkinStoreError.versionAlreadyInstalled(reference)
            }
        } else if policy != .allowDowngrade,
                  let latest,
                  let latestVersion = PocketPadSemanticVersion(latest.reference.version),
                  incomingVersion < latestVersion {
            throw PocketPadSkinStoreError.newerVersionInstalled(
                identifier: reference.identifier,
                installedVersion: latest.reference.version
            )
        }

        let directory = destination.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: destination, options: [.atomic])
        } catch {
            throw PocketPadSkinStoreError.cannotWritePackage(error.localizedDescription)
        }

        if fileManager.fileExists(atPath: destination.path),
           installedForIdentifier.contains(where: { $0.reference == reference }) {
            return .replaced(reference)
        }
        if let latest, latest.reference.version != reference.version {
            return .updated(reference, previousVersion: latest.reference.version)
        }
        return .installed(reference)
    }

    @discardableResult
    public func install(
        package: PocketPadSkinPackage,
        policy: PocketPadSkinInstallPolicy = .newerOnly
    ) throws -> PocketPadSkinInstallResult {
        try install(data: PocketPadSkinPackageCodec.encode(package), policy: policy)
    }

    public func remove(_ reference: PocketPadSkinReference) throws {
        let url = try validatedPackageURL(for: reference)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PocketPadSkinStoreError.skinNotInstalled(reference)
        }
        do {
            try fileManager.removeItem(at: url)
            let directory = url.deletingLastPathComponent()
            if (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true {
                try? fileManager.removeItem(at: directory)
            }
        } catch {
            throw PocketPadSkinStoreError.cannotRemovePackage(error.localizedDescription)
        }
    }

    /// Installs first-party presets through the same codec and store path used by community skins.
    public func installBundledSkinsIfNeeded() throws {
        for package in PocketPadBundledSkins.packages {
            _ = try install(package: package, policy: .replaceSameVersion)
        }
    }

    public func packageData(referencedBy profiles: [GamepadConfigurationProfile]) -> [Data] {
        let references = Set(profiles.compactMap(\.skinReference))
        return references.compactMap { try? packageData(for: $0) }
    }

    private func packageURL(for reference: PocketPadSkinReference) -> URL {
        rootURL
            .appendingPathComponent(reference.identifier, isDirectory: true)
            .appendingPathComponent("\(reference.version).\(Self.packageExtension)", isDirectory: false)
    }

    private func validatedPackageURL(for reference: PocketPadSkinReference) throws -> URL {
        guard reference.isValid else { throw PocketPadSkinStoreError.invalidIdentity }
        let identifierDirectory = rootURL.appendingPathComponent(reference.identifier, isDirectory: true)
        let rawPackage = packageURL(for: reference)
        for url in [identifierDirectory, rawPackage] where fileManager.fileExists(atPath: url.path) {
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values?.isSymbolicLink != true else { throw PocketPadSkinStoreError.invalidIdentity }
        }
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let package = rawPackage.standardizedFileURL.resolvingSymlinksInPath()
        guard package.path.hasPrefix(root.path + "/") else {
            throw PocketPadSkinStoreError.invalidIdentity
        }
        return package
    }

    private static func reference(for package: PocketPadSkinPackage) -> PocketPadSkinReference? {
        let manifest = package.manifest.normalized
        guard PocketPadSemanticVersion(manifest.version) != nil else { return nil }
        return PocketPadSkinReference(identifier: manifest.identifier, version: manifest.version)
    }
}

public enum PocketPadBundledSkins {
    public static let packages: [PocketPadSkinPackage] = GamepadThemePreset.allCases.map(makePackage)
    public static let identifiers: Set<String> = Set(packages.map { $0.manifest.identifier })

    private static func makePackage(for preset: GamepadThemePreset) -> PocketPadSkinPackage {
        let baseCustomization = GamepadCustomization.defaultValue.normalized
        let themed = preset.applying(to: baseCustomization)
        let lightBackground = themed.backgroundFillStyle(for: ColorScheme.light)
        let darkBackground = themed.backgroundFillStyle(for: ColorScheme.dark)
        let buttonRules = GameButton.builtInControls.map { button in
            PocketPadSkinButtonRule(
                button: button,
                appearance: appearance(from: themed.buttonCustomization(for: button))
            )
        }
        let baseAppearance = PocketPadSkinAppearance(
            accentStyle: themed.accentStyle,
            showsButtonLabels: themed.showsButtonLabels,
            buttonRules: buttonRules,
            styleLibrary: themed.styleLibrary
        )
        let skin = PocketPadSkin(
            base: baseAppearance,
            variants: [
                PocketPadSkinVariant(
                    id: "light",
                    colorScheme: .light,
                    appearance: PocketPadSkinAppearance(backgroundFillStyle: lightBackground)
                ),
                PocketPadSkinVariant(
                    id: "dark",
                    colorScheme: .dark,
                    appearance: PocketPadSkinAppearance(backgroundFillStyle: darkBackground)
                )
            ]
        )
        let identifier = "com.codybontecou.pocketpad.skin.\(preset.rawValue)"
        return PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: identifier,
                version: "1.0.0",
                name: preset.displayName,
                author: PocketPadSkinAuthor(name: "ThumbConsole"),
                summary: preset.description,
                license: "All Rights Reserved",
                tags: ["bundled", "preset", preset.rawValue]
            ),
            skin: skin
        )
    }

    private static func appearance(from layout: GamepadButtonCustomization) -> PocketPadSkinControlAppearance {
        PocketPadSkinControlAppearance(
            styleID: layout.styleID,
            shape: layout.shape,
            accentStyle: layout.accentStyle,
            visualStyle: layout.visualStyle,
            icon: layout.icon,
            hapticFeedback: layout.hapticFeedback,
            cornerRadius: layout.cornerRadius,
            cornerRadii: layout.cornerRadii,
            shadowStrength: layout.shadowStrength
        )
    }
}
