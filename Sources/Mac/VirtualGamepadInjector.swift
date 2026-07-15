import Darwin
import Foundation
import IOKit
import IOKit.hidsystem

final class VirtualGamepadInjector {
    struct Status: Codable, Equatable, Sendable {
        var isAvailable: Bool
        var isActive: Bool
        var lastError: String?
        var pressedButtons: [VirtualGamepadButton]
        var leftStickX: Double
        var leftStickY: Double
        var rightStickX: Double
        var rightStickY: Double
        var leftTrigger: Double
        var rightTrigger: Double
    }

    private struct State: Equatable {
        var buttons: Set<VirtualGamepadButton> = []
        var leftStickX: Double = 0
        var leftStickY: Double = 0
        var rightStickX: Double = 0
        var rightStickY: Double = 0
        var leftTrigger: Double = 0
        var rightTrigger: Double = 0
    }

    private let lock = NSLock()
    private let deviceQueue = DispatchQueue(label: "ThumbConsole.VirtualGamepadHID", qos: .userInteractive)
    private var virtualDevice: IOHIDUserDevice?
    private var state = State()
    private(set) var lastError: String?

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return virtualDevice != nil
    }

    func status() -> Status {
        lock.lock()
        defer { lock.unlock() }
        return Status(
            isAvailable: virtualDevice != nil || lastError == nil,
            isActive: virtualDevice != nil,
            lastError: lastError,
            pressedButtons: state.buttons.sortedForDisplay,
            leftStickX: state.leftStickX,
            leftStickY: state.leftStickY,
            rightStickX: state.rightStickX,
            rightStickY: state.rightStickY,
            leftTrigger: state.leftTrigger,
            rightTrigger: state.rightTrigger
        )
    }

    @discardableResult
    func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return startLocked()
    }

    func stop() {
        lock.lock()
        let device = virtualDevice
        virtualDevice = nil
        state = State()
        lock.unlock()

        if let device {
            IOHIDUserDeviceCancel(device)
        }
    }

    func reset() {
        lock.lock()
        state = State()
        sendReportLocked()
        lock.unlock()
    }

    func setButton(_ button: VirtualGamepadButton, pressed: Bool) {
        lock.lock()
        guard startLocked() else {
            lock.unlock()
            return
        }
        if pressed {
            state.buttons.insert(button)
        } else {
            state.buttons.remove(button)
        }
        sendReportLocked()
        lock.unlock()
    }

    func setStick(_ stick: VirtualGamepadStick, x: Double, y: Double) {
        lock.lock()
        guard startLocked() else {
            lock.unlock()
            return
        }
        let x = Self.clamp(x, lower: -1, upper: 1)
        let y = Self.clamp(y, lower: -1, upper: 1)
        switch stick {
        case .left:
            state.leftStickX = x
            state.leftStickY = y
        case .right:
            state.rightStickX = x
            state.rightStickY = y
        }
        sendReportLocked()
        lock.unlock()
    }

    func setTrigger(_ trigger: VirtualGamepadTrigger, value: Double) {
        lock.lock()
        guard startLocked() else {
            lock.unlock()
            return
        }
        let value = Self.clamp(value, lower: 0, upper: 1)
        switch trigger {
        case .left:
            state.leftTrigger = value
        case .right:
            state.rightTrigger = value
        }
        sendReportLocked()
        lock.unlock()
    }

    private func startLocked() -> Bool {
        if virtualDevice != nil { return true }

        let properties: [String: Any] = [
            kIOHIDReportDescriptorKey as String: Data(Self.reportDescriptor),
            kIOHIDVendorIDKey as String: 0xCB01,
            kIOHIDProductIDKey as String: 0x5050,
            kIOHIDVersionNumberKey as String: 1,
            kIOHIDTransportKey as String: "Virtual",
            kIOHIDManufacturerKey as String: "ThumbConsole",
            kIOHIDProductKey as String: "ThumbConsole Virtual Gamepad",
            kIOHIDSerialNumberKey as String: "PocketPad-Gamepad-1",
            kIOHIDPrimaryUsagePageKey as String: 0x01,
            kIOHIDPrimaryUsageKey as String: 0x05
        ]

        guard let createdDevice = IOHIDUserDeviceCreateWithProperties(
            kCFAllocatorDefault,
            properties as CFDictionary,
            IOOptionBits(1)
        ) else {
            lastError = "Could not create IOHIDUserDevice. macOS requires the com.apple.developer.hid.virtual.device entitlement for virtual gamepad output."
            return false
        }

        IOHIDUserDeviceRegisterGetReportBlock(createdDevice) { _, _, report, reportLength in
            let fallbackReport = [UInt8](repeating: 0, count: 10)
            let copyCount = min(Int(reportLength.pointee), fallbackReport.count)
            if copyCount > 0 {
                fallbackReport.withUnsafeBufferPointer { source in
                    report.update(from: source.baseAddress!, count: copyCount)
                }
            }
            reportLength.pointee = copyCount
            return kIOReturnSuccess
        }
        IOHIDUserDeviceRegisterSetReportBlock(createdDevice) { _, _, _, _ in
            kIOReturnSuccess
        }
        IOHIDUserDeviceSetDispatchQueue(createdDevice, deviceQueue)
        IOHIDUserDeviceActivate(createdDevice)

        virtualDevice = createdDevice
        lastError = nil
        sendReportLocked()
        return true
    }

    private func sendReportLocked() {
        guard let device = virtualDevice else { return }
        let report = reportBytes(for: state)
        let result = report.withUnsafeBufferPointer { pointer in
            IOHIDUserDeviceHandleReportWithTimeStamp(
                device,
                mach_absolute_time(),
                pointer.baseAddress!,
                pointer.count
            )
        }
        if result != kIOReturnSuccess {
            lastError = "IOHIDUserDevice report dispatch failed: 0x\(String(UInt32(bitPattern: result), radix: 16))"
        }
    }

    private func reportBytes(for state: State) -> [UInt8] {
        var buttons: UInt16 = 0
        for button in state.buttons {
            guard let bit = Self.buttonBitIndex(for: button) else { continue }
            buttons |= UInt16(1) << UInt16(bit)
        }

        return [
            0x01,
            UInt8(buttons & 0x00ff),
            UInt8((buttons >> 8) & 0x00ff),
            Self.hatValue(for: state.buttons),
            Self.signedAxisByte(state.leftStickX),
            Self.signedAxisByte(state.leftStickY),
            Self.signedAxisByte(state.rightStickX),
            Self.signedAxisByte(state.rightStickY),
            Self.unsignedAxisByte(state.leftTrigger),
            Self.unsignedAxisByte(state.rightTrigger)
        ]
    }

    private static func buttonBitIndex(for button: VirtualGamepadButton) -> Int? {
        switch button {
        case .south: 0
        case .east: 1
        case .west: 2
        case .north: 3
        case .leftShoulder: 4
        case .rightShoulder: 5
        case .leftTriggerButton: 6
        case .rightTriggerButton: 7
        case .select: 8
        case .start: 9
        case .home: 10
        case .leftStickPress: 11
        case .rightStickPress: 12
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight: nil
        }
    }

    private static func hatValue(for buttons: Set<VirtualGamepadButton>) -> UInt8 {
        let up = buttons.contains(.dpadUp)
        let down = buttons.contains(.dpadDown)
        let left = buttons.contains(.dpadLeft)
        let right = buttons.contains(.dpadRight)

        switch (up, down, left, right) {
        case (true, false, false, false): return 0
        case (true, false, false, true): return 1
        case (false, false, false, true): return 2
        case (false, true, false, true): return 3
        case (false, true, false, false): return 4
        case (false, true, true, false): return 5
        case (false, false, true, false): return 6
        case (true, false, true, false): return 7
        default: return 8
        }
    }

    private static func signedAxisByte(_ value: Double) -> UInt8 {
        let clamped = clamp(value, lower: -1, upper: 1)
        let scaled = Int(round(clamped * 127))
        return UInt8(bitPattern: Int8(max(-127, min(127, scaled))))
    }

    private static func unsignedAxisByte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, Int(round(clamp(value, lower: 0, upper: 1) * 255)))))
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }

    private static let reportDescriptor: [UInt8] = [
        0x05, 0x01,
        0x09, 0x05,
        0xA1, 0x01,
        0x85, 0x01,
        0x05, 0x09,
        0x19, 0x01,
        0x29, 0x10,
        0x15, 0x00,
        0x25, 0x01,
        0x75, 0x01,
        0x95, 0x10,
        0x81, 0x02,
        0x05, 0x01,
        0x09, 0x39,
        0x15, 0x00,
        0x25, 0x08,
        0x35, 0x00,
        0x46, 0x3B, 0x01,
        0x65, 0x14,
        0x75, 0x04,
        0x95, 0x01,
        0x81, 0x42,
        0x75, 0x04,
        0x95, 0x01,
        0x81, 0x03,
        0x09, 0x30,
        0x09, 0x31,
        0x09, 0x32,
        0x09, 0x35,
        0x15, 0x81,
        0x25, 0x7F,
        0x75, 0x08,
        0x95, 0x04,
        0x81, 0x02,
        0x09, 0x33,
        0x09, 0x34,
        0x15, 0x00,
        0x26, 0xFF, 0x00,
        0x75, 0x08,
        0x95, 0x02,
        0x81, 0x02,
        0xC0
    ]
}
