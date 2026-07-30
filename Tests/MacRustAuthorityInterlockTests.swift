import Foundation
import XCTest

final class MacRustAuthorityInterlockTests: XCTestCase {
    func testLegacyBackendLeaseUsesExactExclusiveAuthorityLock() throws {
        let stateDirectory = try temporaryStateDirectory()
        var first: MacLegacyAuthorityLease? = try .acquire(stateDirectory: stateDirectory)
        XCTAssertThrowsError(try MacLegacyAuthorityLease.acquire(stateDirectory: stateDirectory)) {
            XCTAssertTrue($0 is MacLegacyAuthorityLease.LeaseError)
        }
        first = nil
        XCTAssertNoThrow(try MacLegacyAuthorityLease.acquire(stateDirectory: stateDirectory))
    }

    func testSymlinkedAuthorityLockFailsClosed() throws {
        let stateDirectory = try temporaryStateDirectory()
        let target = stateDirectory.appendingPathComponent("target")
        try Data().write(to: target)
        try FileManager.default.createSymbolicLink(
            at: stateDirectory.appendingPathComponent("runtime.lock"),
            withDestinationURL: target
        )
        XCTAssertThrowsError(try MacLegacyAuthorityLease.acquire(stateDirectory: stateDirectory)) {
            XCTAssertTrue($0 is MacLegacyAuthorityLease.LeaseError)
        }
    }

    private func temporaryStateDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumble-authority-interlock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
}
