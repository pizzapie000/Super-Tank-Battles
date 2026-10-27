import AppKit
import CoreBluetooth
import IOBluetooth
import Darwin

final class Remote: NSObject {
    let device: IOBluetoothDevice?
    let identity: String
    let slot: Int
    var state = WiiState()
    var queue: [WiiCommand] = []
    var pending: WiiCommand?
    var sentAt = 0.0
    var retries = 0
    var lastInput = 0.0
    var lastProbe = -100.0
    var message = "Press a remote button to wake it."
    var ready = false
    var lastFailure = ""
    var hid: WiiHIDRemote?
    var receivedInput = false
    var inputTimes: [Double] = []
    var irTimes: [Double] = []
    var onReport: (() -> Void)?

    init(_ device: IOBluetoothDevice?, slot: Int, identity: String? = nil) {
        self.device = device; self.slot = slot
        self.identity = identity ?? device?.addressString ?? "remote-\(slot)"
    }
    var now: Double { ProcessInfo.processInfo.systemUptime }
    var live: Bool { ready && now - lastInput < 1.0 }
    func receive(_ report: [UInt8]) {
        var bytes = report
        if bytes.first == 0xa1 { bytes.removeFirst() }
        let attached = state.extensionAttached
        if state.decode(bytes) {
            receivedInput = true
            lastInput = now
            inputTimes.append(lastInput)
            if state.tracking.quality == "tracked" { irTimes.append(lastInput) }
            inputTimes.removeAll { lastInput - $0 > 1 }
            irTimes.removeAll { lastInput - $0 > 1 }
            message = (hid == nil ? "" : "Native controller connected. ") + (state.nunchuk ? (state.pointer == nil ? "Nunchuk ready. Point at the powered sensor bar." : "Nunchuk and pointer ready.") : "Attach a wired Nunchuk.")
            onReport?()
        }
        guard let id = bytes.first else { return }
        if id == 0x20 && bytes.count >= 7 {
            if state.extensionAttached && (!attached || !state.nunchuk) && !queue.contains(where: { $0.readAddress == 0xfa }) {
                queue += WiiCommand.nunchuk
            }
            queue.append(WiiCommand(report: 0x12, data: [4, 0x37]))
        }
        if let command = pending {
            if id == 0x22 && bytes.count >= 5 && bytes[3] == command.report {
                if bytes[4] == 0 { pending = nil; retries = 0 }
                else { message = "Remote rejected report \(command.report): \(bytes[4]). Retrying…"; sentAt = 0 }
            } else if id == 0x21 && bytes.count >= 6 && command.readAddress == Int(bytes[4]) << 8 | Int(bytes[5]) {
                if bytes[3] & 0x0f == 0 { pending = nil; retries = 0 }
                else { message = "Extension read failed: \(bytes[3] & 15). Retrying…"; sentAt = 0 }
            }
        }
    }
    func attach(_ native: WiiHIDRemote) {
        if hid === native && native.active { return }
        disconnect()
        hid = native
        native.onInput = { [weak self] bytes in self?.receive(bytes) }
        let result = native.open()
        guard result == kIOReturnSuccess else { failed("Native controller access", result); return }
        ready = true; lastFailure = ""
        message = "Native controller connected. Initializing Nunchuk and camera…"
        queue = [WiiCommand(report: 0x11, data: [UInt8(0x10 << slot)])] + WiiCommand.camera
    }
    func disconnect() {
        ready = false; lastInput = 0
        pending = nil; queue = []; state = WiiState()
        inputTimes = []; irTimes = []
        let oldHID = hid
        hid = nil
        oldHID?.close()
    }
    func failed(_ context: String, _ code: IOReturn) {
        disconnect()
        lastFailure = "\(context) failed (\(String(format: "0x%08x", code)))"
        message = lastFailure + ". Close other controller apps, press A, then Scan."
        NSLog("Wii Remote %d: %@", slot + 1, lastFailure)
    }
    func tick() {
        guard ready, let hid = hid, hid.active else { return }
        if now - lastInput > 1 && queue.isEmpty && pending == nil && now - lastProbe > 3 {
            lastProbe = now
            message = "No recent input. Wake the remote or use Retry Camera."
            queue += [WiiCommand(report: 0x15, data: [0]), WiiCommand(report: 0x12, data: [4, 0x37])]
        }
        if now - sentAt < 0.06 { return }
        if pending != nil && now - sentAt < 0.8 { return }
        if pending != nil {
            retries += 1
            if retries > 2 {
                message = "A setup report timed out. Use Retry Camera, or reconnect the Nunchuk."
                pending = nil; retries = 0
            }
        }
        if pending == nil && !queue.isEmpty { pending = queue.removeFirst() }
        guard let command = pending else { return }
        let result = hid.send(command)
        sentAt = now
        if result != kIOReturnSuccess { failed("Sending remote report", result) }
        else if !command.waits { pending = nil; retries = 0 }
    }
    var snapshot: [String: Any] {
        let time = now
        let connected = ready && time - lastInput < 1
        let pointer = connected ? state.tracking.pointer(at: time) : nil
        return ["slot": slot, "id": identity, "name": "Wii Remote \(slot + 1)", "transport": hid == nil ? "waiting-for-native-hid" : "native-hid",
         "connected": connected, "nunchuk": state.nunchuk, "stick": connected ? state.stick : [0, 0],
         "buttons": connected ? state.buttons : 0, "c": connected && state.c, "z": connected && state.z,
         "ir": pointer as Any? ?? NSNull(), "dots": state.dots,
         "ir_seq": state.tracking.sequence, "ir_status": pointer == nil ? "lost" : state.tracking.quality,
         "ir_time": pointer == nil ? 0 : state.tracking.lastSample,
         "input_hz": inputTimes.filter { time - $0 <= 1 }.count,
         "ir_hz": irTimes.filter { time - $0 <= 1 }.count,
         "battery": state.battery, "status": message]
    }
}

final class Bridge: NSObject, NSApplicationDelegate, CBCentralManagerDelegate {
    var remotes: [Remote] = []
    var timer: Timer?
    var window: NSWindow!
    var status: NSTextField!
    var socketFD: Int32 = -1
    var destination = sockaddr_in()
    var token = ""
    var port: UInt16 = 42430
    var sequence = 0
    var ticks = 0
    var idleTest = false
    var windowTest = false
    var windowChecks = 0
    var ownerPID: pid_t = 0
    var bluetooth: CBCentralManager?
    var bluetoothMessage = "Waiting for Bluetooth permission…"
    var pairingPaused = false
    var hidError = ""
    let hidMonitor = WiiHIDMonitor()
    var delivery = WiiDeliverySchedule()
    var inputActivity: NSObjectProtocol?
    var connectionSummary = "Bridge connected. Pair or wake your Wii Remotes."

    func updateInputActivity() {
        let needed = !idleTest && !token.isEmpty && !pairingPaused && remotes.contains { $0.live }
        if needed && inputActivity == nil {
            inputActivity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical], reason: "Deliver active Wii controller input to Super Tank Battles")
        } else if !needed, let activity = inputActivity {
            ProcessInfo.processInfo.endActivity(activity)
            inputActivity = nil
        }
    }

    func makeRemote(_ device: IOBluetoothDevice?, slot: Int, identity: String? = nil) -> Remote {
        let remote = Remote(device, slot: slot, identity: identity)
        remote.onReport = { [weak self] in
            self?.updateInputActivity()
            self?.sendSnapshot(changed: true)
        }
        return remote
    }
    var pairingAppRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "org.dolphin-emu.WiimotePair.local").isEmpty ||
        !NSRunningApplication.runningApplications(withBundleIdentifier: "org.dolphin-emu.WiimotePair").isEmpty
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--port"), i + 1 < args.count, let p = UInt16(args[i + 1]) { port = p }
        if let i = args.firstIndex(of: "--token"), i + 1 < args.count { token = args[i + 1] }
        if let i = args.firstIndex(of: "--owner-pid"), i + 1 < args.count, let pid = Int32(args[i + 1]), pid > 0 { ownerPID = pid }
        windowTest = args.contains("--window-test")
        idleTest = args.contains("--transport-test") || windowTest
        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_port = port.bigEndian
        destination.sin_addr.s_addr = inet_addr("127.0.0.1")
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 670, height: 440), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Super Tank Battles — Wii Remote Bridge"
        // AppKit must not release this retained window when its close button is used.
        window.isReleasedWhenClosed = false
        window.center()
        let heading = NSTextField(labelWithString: "Wii Remote + Nunchuk")
        heading.font = .boldSystemFont(ofSize: 24); heading.frame = NSRect(x: 25, y: 380, width: 620, height: 35)
        window.contentView?.addSubview(heading)
        let help = NSTextField(wrappingLabelWithString: "1. Pair with red SYNC. Wait for Wii Remote Connected in WiimotePair.\n2. Quit WiimotePair and other Wii apps. Attach each Nunchuk.\n3. Press A to reconnect, then Scan. Power your sensor bar.\n4. Return to the game's Wii Remote Setup to calibrate each pointer.")
        help.frame = NSRect(x: 25, y: 268, width: 620, height: 100)
        window.contentView?.addSubview(help)
        status = NSTextField(wrappingLabelWithString: "Waiting for paired Wii Remotes…")
        status.frame = NSRect(x: 25, y: 76, width: 620, height: 175)
        status.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        window.contentView?.addSubview(status)
        for (title, action, x) in [("Pair Remotes", #selector(pair), 25.0), ("Scan", #selector(scan), 175.0), ("Retry Camera", #selector(retry), 295.0), ("Quit Bridge", #selector(stop), 465.0)] {
            let button = NSButton(title: title, target: self, action: action)
            button.frame = NSRect(x: x, y: 20, width: 140, height: 34)
            window.contentView?.addSubview(button)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let inputTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        inputTimer.tolerance = 0
        RunLoop.main.add(inputTimer, forMode: .common)
        timer = inputTimer
        hidMonitor.onAttach = { [weak self] device in self?.attachHID(device) }
        hidMonitor.onRemove = { [weak self] device in
            guard let remote = self?.remotes.first(where: { $0.hid === device }) else { return }
            remote.disconnect()
            remote.message = "Controller disconnected. Press A to reconnect, then Scan."
        }
        // Ask asynchronously from this app's own privacy identity, before IOBluetooth.
        if !idleTest && !token.isEmpty {
            bluetooth = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: bluetoothMessage = "Bluetooth ready."; discover()
        case .unauthorized: bluetoothMessage = "Bluetooth access is off. Enable Wii Remote Bridge in System Settings → Privacy & Security → Bluetooth, then choose Scan."
        case .poweredOff: bluetoothMessage = "Turn on Bluetooth on your Mac, then choose Scan."
        case .unsupported: bluetoothMessage = "Bluetooth is unavailable on this Mac."
        default: bluetoothMessage = "Waiting for Bluetooth…"
        }
    }
    @objc func scan() {
        discover(forceRetry: true)
    }
    func discover(forceRetry: Bool = false) {
        guard !idleTest && !token.isEmpty else { return }
        guard bluetooth?.state == .poweredOn else { return }
        guard !pairingAppRunning else { return }
        let nativeResult = hidMonitor.start()
        hidError = nativeResult == kIOReturnSuccess ? "" : "Native controller listener failed (\(String(format: "0x%08x", nativeResult))). Close other controller apps and Scan again."
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).filter { ($0.name ?? "").hasPrefix("Nintendo RVL-CNT-01") }
        for device in devices where !remotes.contains(where: { wiiBluetoothAddress($0.identity) == wiiBluetoothAddress(device.addressString) }) && remotes.count < 4 {
            let remote = makeRemote(device, slot: nextSlot())
            remote.message = "Paired. Press A; waiting for the native controller connection…"
            remotes.append(remote)
        }
        for remote in remotes {
            if forceRetry && remote.hid == nil {
                remote.message = "Press A; waiting for the native controller connection…"
            }
        }
    }
    func nextSlot() -> Int { (0..<4).first { slot in !remotes.contains(where: { $0.slot == slot }) } ?? 0 }
    func attachHID(_ native: WiiHIDRemote) {
        guard !idleTest && !token.isEmpty && !pairingAppRunning else { return }
        if let remote = remotes.first(where: { $0.identity == native.identity || (native.address != nil && wiiBluetoothAddress($0.identity) == native.address) }) {
            remote.attach(native); return
        }
        // A paired entry with no input is a placeholder, safe to replace with an
        // identified native controller. Never reassign a controller that has sent input.
        if let index = remotes.firstIndex(where: { !$0.receivedInput && $0.hid == nil && !$0.ready }) {
            let previous = remotes[index]
            previous.disconnect()
            let remote = makeRemote(nil, slot: previous.slot, identity: native.identity)
            remotes[index] = remote
            remote.attach(native)
        } else if remotes.count < 4 {
            let remote = makeRemote(nil, slot: nextSlot(), identity: native.identity)
            remotes.append(remote); remote.attach(native)
        }
    }
    @objc func pair() {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/WiimotePair.app")
        if FileManager.default.fileExists(atPath: path.path) { NSWorkspace.shared.open(path) }
        else { NSWorkspace.shared.open(URL(string: "https://github.com/dolphin-emu/WiimotePair/releases/latest")!) }
    }
    @objc func retry() { for remote in remotes where remote.ready { remote.queue += WiiCommand.camera + WiiCommand.nunchuk } }
    @objc func stop() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }
    func tick() {
        ticks += 1
        if ownerPID > 0 && ticks % 60 == 0 && kill(ownerPID, 0) != 0 && errno == ESRCH { NSApp.terminate(nil); return }
        if windowTest && ticks <= 40 {
            if ticks % 2 == 1 { window.close() }
            else {
                _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
                precondition(window.isVisible && !window.isReleasedWhenClosed)
                windowChecks += 1
            }
        }
        let pairing = !idleTest && !token.isEmpty && (ticks % 30 == 1 ? pairingAppRunning : pairingPaused)
        if pairing && !pairingPaused {
            hidMonitor.stop()
            for remote in remotes { remote.disconnect() }
        } else if !pairing && pairingPaused {
            discover(forceRetry: true)
        }
        pairingPaused = pairing
        if !pairing {
            for remote in remotes { remote.tick() }
            if ticks % 300 == 0 { discover() }
        }
        updateInputActivity()
        let pairingHelp = "Pairing is in progress. Wait for Wii Remote Connected in WiimotePair, then QUIT WiimotePair and press A to wake the remote, then choose Scan here. A steady player light appears after the bridge connects."
        let summary = windowTest ? "Window reopen checks: \(windowChecks)/20" : (pairing ? pairingHelp : (!hidError.isEmpty ? hidError : (bluetooth?.state == .poweredOn ? "Bridge connected. Pair or wake your Wii Remotes." : bluetoothMessage)))
        connectionSummary = summary
        sendSnapshot()
        if ticks % 15 == 0 {
            status.stringValue = token.isEmpty ? "Open Wii Remote Setup in the game and choose Start Wii Bridge.\nThis window needs the game's local connection to send input." : ((idleTest || pairing || !hidError.isEmpty) ? summary : (bluetooth?.state != .poweredOn ? bluetoothMessage : (remotes.isEmpty ? "No Wii Remotes connected yet.\nFor a paired remote, press A and Scan.\nFor first pairing, open Pair Remotes and press red SYNC." : remotes.map { "Remote \($0.slot + 1): \($0.message)" }.joined(separator: "\n\n"))))
        }
        if idleTest && ticks >= (windowTest ? 180 : 60) { NSApp.terminate(nil) }
    }

    func sendSnapshot(changed: Bool = false) {
        guard !token.isEmpty, delivery.request(changed: changed, at: ProcessInfo.processInfo.systemUptime) else { return }
        sequence += 1
        let packet: [String: Any] = ["version": 1, "token": token, "seq": sequence, "pid": Int(getpid()), "status": connectionSummary, "devices": remotes.map(\.snapshot)]
        if let bytes = try? JSONSerialization.data(withJSONObject: packet) {
            bytes.withUnsafeBytes { buffer in
                withUnsafePointer(to: &destination) { address in
                    address.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = sendto(socketFD, buffer.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                }
            }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let activity = inputActivity { ProcessInfo.processInfo.endActivity(activity); inputActivity = nil }
        hidMonitor.stop()
        for remote in remotes { remote.disconnect() }
        if socketFD >= 0 { close(socketFD) }
    }
}

@main struct Main {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            protocolSelfTest()
            precondition(wiiBluetoothAddress("00-1A-2B-3C-4D-5E") == "00:1a:2b:3c:4d:5e")
            precondition(wiiBluetoothAddress("not-a-bluetooth-address") == nil)
            precondition(WiiHIDRemote.report(0x22, bytes: [0, 0, 0x16, 0]) == [0x22, 0, 0, 0x16, 0])
            precondition(WiiHIDRemote.report(0x22, bytes: [0x22, 0, 0, 0x16, 0]) == [0x22, 0, 0, 0x16, 0])
            let remote = Remote(nil, slot: 0)
            remote.ready = true
            var report: [UInt8] = [0x37, 0, 4, 128, 128, 170, 44, 94, 0x56, 188, 94, 255, 255, 255, 255, 255, 200, 128, 1, 1, 1, 255]
            remote.receive(report)
            report[8] |= 0x0f; report[9] = 255; report[10] = 255
            remote.receive(report)
            for _ in 0..<60 { _ = remote.snapshot }
            precondition(remote.snapshot["input_hz"] as? Int == 2 && remote.snapshot["ir_hz"] as? Int == 1)
            precondition(remote.snapshot["ir_status"] as? String == "partial")
            let other = Remote(nil, slot: 1)
            precondition(other.snapshot["input_hz"] as? Int == 0)
            remote.disconnect()
            precondition(remote.snapshot["input_hz"] as? Int == 0 && remote.state.tracking.sequence == 0)
            let coordinator = Bridge()
            coordinator.token = "self-test-only"
            let awakeRemote = coordinator.makeRemote(nil, slot: 0)
            coordinator.remotes = [awakeRemote]
            awakeRemote.ready = true
            awakeRemote.lastInput = awakeRemote.now
            coordinator.updateInputActivity()
            precondition(coordinator.inputActivity != nil)
            awakeRemote.disconnect()
            coordinator.updateInputActivity()
            precondition(coordinator.inputActivity == nil)
            print("Wii active-input activity lifecycle checks: PASS")
            print("Wii per-remote report-rate checks: PASS")
            print("Wii native HID framing checks: PASS")
            return
        }
        if CommandLine.arguments.contains("--fixture-json") || CommandLine.arguments.contains("--hid-fixture-json") {
            var state = WiiState()
            _ = state.decode([0x20, 0, 0, 2, 0, 0, 192])
            _ = state.decode([0x21, 0, 0, 0x50, 0, 0xfa, 0, 0, 0xa4, 0x20, 0, 0])
            let stream: [UInt8] = [0x37, 0, 4, 128, 128, 170, 44, 94, 0x56, 188, 94, 255, 255, 255, 255, 255, 200, 128, 1, 1, 1, 255]
            _ = state.decode(CommandLine.arguments.contains("--hid-fixture-json") ? WiiHIDRemote.report(0x37, bytes: Array(stream.dropFirst())) : stream)
            let fixture: [String: Any] = ["slot": 0, "id": "test-fixture-only", "connected": true, "nunchuk": state.nunchuk, "stick": state.stick, "buttons": state.buttons, "c": state.c, "z": state.z, "ir": state.pointer!, "status": "Protocol test fixture"]
            let bytes = try! JSONSerialization.data(withJSONObject: fixture, options: [.sortedKeys])
            print(String(data: bytes, encoding: .utf8)!); return
        }
        let app = NSApplication.shared
        let bridge = Bridge()
        app.setActivationPolicy(.regular)
        app.delegate = bridge
        app.run()
        withExtendedLifetime(bridge) {}
    }
}
