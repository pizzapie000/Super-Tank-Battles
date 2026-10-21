import Foundation
import IOKit.hid

func wiiBluetoothAddress(_ value: String?) -> String? {
    guard let value = value else { return nil }
    let compact = value.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").lowercased()
    guard compact.count == 12 && compact.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
    let bytes = Array(compact)
    return stride(from: 0, to: 12, by: 2).map { String(bytes[$0...($0 + 1)]) }.joined(separator: ":")
}

final class WiiHIDRemote {
    let device: IOHIDDevice
    let registryID: UInt64
    let address: String?
    let identity: String
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    var active = false
    var onInput: (([UInt8]) -> Void)?

    init(_ device: IOHIDDevice) {
        self.device = device
        var entryID: UInt64 = 0
        _ = IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entryID)
        if entryID == 0 { entryID = UInt64(CFHash(device)) }
        registryID = entryID
        let keys = [kIOHIDSerialNumberKey, "PhysicalDeviceUniqueID", "DeviceAddress", "BluetoothDeviceAddress"]
        address = keys.compactMap { IOHIDDeviceGetProperty(device, $0 as CFString) as? String }.compactMap(wiiBluetoothAddress).first
        identity = address ?? "wii-hid-\(entryID)"
    }

    func open() -> IOReturn {
        if active { return kIOReturnSuccess }
        let result = IOHIDDeviceOpen(device, 0)
        guard result == kIOReturnSuccess else { return result }
        active = true
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, result, _, _, reportID, report, length in
            guard let context = context, result == kIOReturnSuccess, length > 0, length <= 64 else { return }
            let remote = Unmanaged<WiiHIDRemote>.fromOpaque(context).takeUnretainedValue()
            guard remote.active else { return }
            remote.onInput?(WiiHIDRemote.report(reportID, bytes: Array(UnsafeBufferPointer(start: report, count: length))))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        return result
    }

    static func report(_ reportID: UInt32, bytes: [UInt8]) -> [UInt8] {
        guard reportID > 0 && reportID <= 255 else { return bytes }
        return bytes.first == UInt8(reportID) ? bytes : [UInt8(reportID)] + bytes
    }

    func send(_ command: WiiCommand) -> IOReturn {
        guard active else { return kIOReturnNotOpen }
        // IOHIDSetReport takes the report ID and payload, without Bluetooth's A2 header.
        let bytes = Array(command.packet.dropFirst())
        return bytes.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(command.report), $0.baseAddress!, $0.count)
        }
    }

    func close() {
        guard active else { return }
        active = false
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, 0)
        onInput = nil
    }

    deinit { close(); buffer.deallocate() }
}

final class WiiHIDMonitor {
    var manager: IOHIDManager?
    var devices: [UInt64: WiiHIDRemote] = [:]
    var onAttach: ((WiiHIDRemote) -> Void)?
    var onRemove: ((WiiHIDRemote) -> Void)?

    func start() -> IOReturn {
        if manager != nil { scan(); return kIOReturnSuccess }
        let created = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        manager = created
        // Only Nintendo Wii Remotes over Bluetooth; no keyboards, mice or USB adapters.
        let matching: [[String: Any]] = [0x0306, 0x0330].map {
            [kIOHIDVendorIDKey: 0x057e, kIOHIDProductIDKey: $0, kIOHIDTransportKey: "Bluetooth", "GCSyntheticDevice": false]
        }
        IOHIDManagerSetDeviceMatchingMultiple(created, matching as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(created, { context, result, _, device in
            guard let context = context, result == kIOReturnSuccess else { return }
            Unmanaged<WiiHIDMonitor>.fromOpaque(context).takeUnretainedValue().found(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(created, { context, _, _, device in
            guard let context = context else { return }
            Unmanaged<WiiHIDMonitor>.fromOpaque(context).takeUnretainedValue().removed(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(created, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(created, 0)
        if result != kIOReturnSuccess { stop() } else { scan() }
        return result
    }

    func scan() {
        guard let manager = manager, let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
        for device in devices { found(device) }
    }

    func found(_ device: IOHIDDevice) {
        let remote = WiiHIDRemote(device)
        if let existing = devices[remote.registryID] {
            if !existing.active { onAttach?(existing) }
            return
        }
        devices[remote.registryID] = remote
        onAttach?(remote)
    }

    func removed(_ device: IOHIDDevice) {
        var identity: UInt64 = 0
        _ = IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &identity)
        if identity == 0 { identity = UInt64(CFHash(device)) }
        guard let remote = devices.removeValue(forKey: identity) else { return }
        onRemove?(remote)
        remote.close()
    }

    func stop() {
        guard let manager = manager else { return }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        for remote in devices.values { onRemove?(remote); remote.close() }
        devices.removeAll()
        IOHIDManagerClose(manager, 0)
        self.manager = nil
    }

    deinit { stop() }
}
