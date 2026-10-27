import Foundation

// Input callbacks publish immediately; a maintenance timer only flushes a
// coalesced update or supplies a heartbeat. One/four remotes stay bounded.
struct WiiDeliverySchedule {
    var lastSent = -Double.infinity
    var pending = false
    mutating func request(changed: Bool, at time: Double) -> Bool {
        pending = pending || changed
        if time - lastSent < 1.0 / 120 { return false }
        if !pending && time - lastSent < 0.1 { return false }
        lastSent = time; pending = false
        return true
    }
}

// Keep the last measured bar geometry through brief loss of ONE endpoint. Never
// invent motion when the camera sees nothing, or use a lone dot to acquire aim.
struct WiiIRTracker {
    static let grace = 0.18
    var endpoints: [[Double]] = []
    var slots: [Int] = []
    var position: [Double]?
    var lastPair = -Double.infinity
    var lastSample = -Double.infinity
    var sequence = 0
    var quality = "lost"

    func distance(_ a: [Double], _ b: [Double]) -> Double {
        pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2)
    }
    func pointer(at time: Double) -> [Double]? {
        guard time - lastSample <= Self.grace,
              quality != "partial" || time - lastPair <= Self.grace else { return nil }
        return position
    }
    mutating func update(_ dots: [[Double]], slots dotSlots: [Int], at time: Double) {
        position = nil; quality = "lost"
        if dots.count >= 2 {
            var best: [[Double]] = [], bestSlots: [Int] = [], score = Double.infinity
            let recent = endpoints.count == 2 && time - lastPair <= Self.grace
            for i in 0..<dots.count {
                for j in (i + 1)..<dots.count {
                    let separation = distance(dots[i], dots[j])
                    if separation < 0.0001 { continue }
                    var pair = [dots[i], dots[j]], pairSlots = [dotSlots[i], dotSlots[j]]
                    var candidate = -separation
                    if recent {
                        // Camera slots can be reassigned. Match geometry first, then
                        // reject a split LED cluster or a suddenly unrelated pair.
                        let forward = distance(pair[0], endpoints[0]) + distance(pair[1], endpoints[1])
                        let reverse = distance(pair[1], endpoints[0]) + distance(pair[0], endpoints[1])
                        if reverse < forward { pair.reverse(); pairSlots.reverse() }
                        let oldSeparation = distance(endpoints[0], endpoints[1])
                        let ratio = sqrt(separation / oldSeparation)
                        let alignment = ((pair[1][0] - pair[0][0]) * (endpoints[1][0] - endpoints[0][0]) +
                                         (pair[1][1] - pair[0][1]) * (endpoints[1][1] - endpoints[0][1])) / sqrt(separation * oldSeparation)
                        guard ratio >= 0.65 && ratio <= 1.55 && alignment >= 0.7 else { continue }
                        candidate = min(forward, reverse) + abs(separation - oldSeparation)
                    }
                    if candidate < score { best = pair; bestSlots = pairSlots; score = candidate }
                }
            }
            if !best.isEmpty {
                endpoints = best; slots = bestSlots
                lastPair = time; quality = "tracked"
            } else if !recover(dots, slots: dotSlots, at: time) { return }
        } else if !recover(dots, slots: dotSlots, at: time) { return }
        position = [max(0, min(1, (endpoints[0][0] + endpoints[1][0]) / 2)), max(0, min(1, (endpoints[0][1] + endpoints[1][1]) / 2))]
        lastSample = time; sequence += 1
    }

    mutating func recover(_ dots: [[Double]], slots dotSlots: [Int], at time: Double) -> Bool {
        guard !dots.isEmpty, endpoints.count == 2, time - lastPair <= Self.grace else { return false }
        var bestDot = -1, matched = 0, bestDistance = 0.0144
        let separation = distance(endpoints[0], endpoints[1])
        for index in dots.indices {
            let a = distance(dots[index], endpoints[0]), b = distance(dots[index], endpoints[1])
            // A slot number is not an endpoint identity. Refuse an ambiguous
            // midpoint instead of switching to the opposite end of the bar.
            if abs(a - b) <= separation * 0.08 { continue }
            let nearest = min(a, b)
            if nearest < bestDistance { bestDot = index; matched = a < b ? 0 : 1; bestDistance = nearest }
        }
        guard bestDot >= 0 else { return false }
        let delta = [dots[bestDot][0] - endpoints[matched][0], dots[bestDot][1] - endpoints[matched][1]]
        endpoints = endpoints.map { [$0[0] + delta[0], $0[1] + delta[1]] }
        slots[matched] = dotSlots[bestDot]
        quality = "partial"
        return true
    }
}

// Original implementation from the documented Wii Remote report formats.
// Protocol references and third-party utility provenance are in NOTICES.txt.
struct WiiState {
    var buttons = 0
    var extensionAttached = false
    var nunchuk = false
    var stick = [0.0, 0.0]
    var rawStick = [128, 128]
    var c = false
    var z = false
    var battery = 0.0
    var dots: [[Double]] = []
    var tracking = WiiIRTracker()
    var calibration = [35, 128, 228, 27, 128, 220] // min/center/max, X then Y

    // Returns true only for a complete streaming input report.
    mutating func decode(_ packet: [UInt8], at time: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        let b = packet.first == 0xa1 ? Array(packet.dropFirst()) : packet
        guard b.count >= 3 else { return false }
        let id = b[0]
        if id == 0x20, b.count >= 7 {
            extensionAttached = b[3] & 2 != 0
            battery = min(1, Double(b[6]) / 192)
            if !extensionAttached { nunchuk = false; clearExtension() }
        }
        if id == 0x21, b.count >= 6 {
            let count = Int(b[3] >> 4) + 1
            let address = Int(b[4]) << 8 | Int(b[5])
            guard b[3] & 0x0f == 0, b.count >= 6 + count else { return false }
            let value = Array(b[6..<(6 + count)])
            if address == 0x00fa, count == 6 {
                nunchuk = value == [0, 0, 0xa4, 0x20, 0, 0]
                if !nunchuk { clearExtension() }
            } else if address == 0x0020, count == 16 {
                let c = value.map(Int.init)
                if c[9] < c[10], c[10] < c[8], c[12] < c[13], c[13] < c[11] {
                    calibration = [c[9], c[10], c[8], c[12], c[13], c[11]]
                }
            }
            return false
        }
        // 0x37 = buttons, acceleration, 10-byte basic IR, six extension bytes.
        guard id == 0x37, b.count >= 22 else { return false }
        buttons = Int(b[1] & 0x1f) << 8 | Int(b[2] & 0x9f)
        dots = []
        var dotSlots: [Int] = []
        for offset in [6, 11] {
            let high = Int(b[offset + 2])
            let points = [
                [Int(b[offset]) | ((high & 0x30) << 4), Int(b[offset + 1]) | ((high & 0xc0) << 2)],
                [Int(b[offset + 3]) | ((high & 3) << 8), Int(b[offset + 4]) | ((high & 0x0c) << 6)]
            ]
            for (index, point) in points.enumerated() where point[0] < 1023 && point[1] < 768 {
                dots.append([Double(point[0]) / 1023, Double(point[1]) / 767])
                dotSlots.append((offset == 6 ? 0 : 2) + index)
            }
        }
        tracking.update(dots, slots: dotSlots, at: time)
        let ext = Array(b[16..<22])
        if nunchuk && ext != Array(repeating: 0xff, count: 6) && ext != Array(repeating: 0, count: 6) {
            rawStick = [Int(ext[0]), Int(ext[1])]
            stick = [axis(rawStick[0], 0), -axis(rawStick[1], 3)]
            c = ext[5] & 2 == 0
            z = ext[5] & 1 == 0
        } else { clearExtension() }
        return true
    }

    mutating func clearExtension() { stick = [0, 0]; c = false; z = false }
    func axis(_ value: Int, _ at: Int) -> Double {
        let center = calibration[at + 1]
        let range = value < center ? center - calibration[at] : calibration[at + 2] - center
        return max(-1, min(1, Double(value - center) / Double(max(1, range))))
    }
    var pointer: [Double]? {
        tracking.pointer(at: ProcessInfo.processInfo.systemUptime)
    }
}

struct WiiCommand {
    var report: UInt8
    var data: [UInt8]
    var readAddress: Int? = nil
    var waits: Bool { report == 0x16 || report == 0x17 }
    var packet: [UInt8] { [0xa2, report] + data }
    static func write(_ address: UInt32, _ values: [UInt8]) -> WiiCommand {
        precondition(values.count <= 16)
        return WiiCommand(report: 0x16, data: bytes(address) + [UInt8(values.count)] + values + Array(repeating: 0, count: 16 - values.count))
    }
    static func read(_ address: UInt32, _ count: UInt16) -> WiiCommand {
        return WiiCommand(report: 0x17, data: bytes(address) + [UInt8(count >> 8), UInt8(count & 255)], readAddress: Int(address & 0xffff))
    }
    static func bytes(_ a: UInt32) -> [UInt8] { [UInt8(a >> 24), UInt8((a >> 16) & 255), UInt8((a >> 8) & 255), UInt8(a & 255)] }
    static var camera: [WiiCommand] { [
        WiiCommand(report: 0x13, data: [4]), WiiCommand(report: 0x1a, data: [4]),
        .write(0x04b00030, [1]),
        .write(0x04b00000, [2, 0, 0, 0x71, 1, 0, 0xaa, 0, 0x64]),
        .write(0x04b0001a, [0x63, 3]), .write(0x04b00033, [1]), .write(0x04b00030, [8]),
        WiiCommand(report: 0x15, data: [0]), WiiCommand(report: 0x12, data: [4, 0x37])
    ] }
    static var nunchuk: [WiiCommand] { [
        .write(0x04a400f0, [0x55]), .write(0x04a400fb, [0]),
        .read(0x04a400fa, 6), .read(0x04a40020, 16), WiiCommand(report: 0x12, data: [4, 0x37])
    ] }
}

func protocolSelfTest() {
    func check(_ condition: Bool, _ message: String) {
        if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    for count in 1...4 {
        var delivery = WiiDeliverySchedule()
        var sent = 0
        // Reproduce a timer that fires only every 120 ms, while each remote
        // supplies 64 reports/s. Delivery must follow input, not that timer.
        var events: [(Double, Bool)] = []
        for remote in 0..<count {
            for sample in 0..<640 { events.append((Double(sample) / 64 + Double(remote) / 512, true)) }
        }
        for tick in 0..<84 { events.append((Double(tick) * 0.12, false)) }
        events.sort { $0.0 < $1.0 }
        for event in events where event.0 < 10 {
            if delivery.request(changed: event.1, at: event.0) { sent += 1 }
        }
        check(sent >= 600 && sent <= 1201, "input-driven delivery must remain 60–120 Hz with a throttled maintenance timer")
    }
    var heartbeat = WiiDeliverySchedule()
    var heartbeats = 0
    for tick in 0..<1000 { if heartbeat.request(changed: false, at: Double(tick) / 1000) { heartbeats += 1 } }
    check(heartbeats >= 9 && heartbeats <= 10, "idle snapshots are limited to heartbeat cadence")
    var burst = WiiDeliverySchedule()
    check(burst.request(changed: true, at: 0), "first input publishes immediately")
    check(!burst.request(changed: true, at: 0.001) && burst.pending, "rapid input coalesces rather than flooding UDP")
    check(burst.request(changed: false, at: 0.01) && !burst.pending, "maintenance flushes a pending latest-state update")
    print("Wii input-driven delivery checks: PASS")
    var state = WiiState()
    _ = state.decode([0x20, 0, 0, 2, 0, 0, 192])
    _ = state.decode([0x21, 0, 0, 0x50, 0, 0xfa, 0, 0, 0xa4, 0x20, 0, 0])
    let report: [UInt8] = [0xa1, 0x37, 0, 0x0c, 128, 128, 170, 44, 94, 0x56, 188, 94, 255, 255, 255, 255, 255, 228, 128, 1, 1, 1, 0xfc]
    check(state.decode(report), "complete 0x37 report")
    check(state.nunchuk && state.stick[0] == 1 && state.stick[1] == 0 && state.c && state.z, "Nunchuk axes and active-low buttons")
    check(state.buttons == 12 && state.dots.count == 2, "remote buttons and empty-dot filtering")
    check(abs(state.pointer![0] - 500.0 / 1023) < 0.00001 && abs(state.pointer![1] - 350.0 / 767) < 0.00001, "packed IR high bits and sensor-bar midpoint")
    check(!state.decode([0x37, 0, 0]), "truncated input ignored")
    _ = state.decode([0x20, 0, 0, 0, 0, 0, 96])
    check(!state.nunchuk && state.stick == [0, 0] && !state.z && state.battery == 0.5, "unplug clears stick and buttons")
    check(WiiCommand.write(0x04a400f0, [0x55]).packet.count == 23, "write report padded to 21 payload bytes")
    check(WiiCommand.camera.contains(where: { $0.report == 0x12 && $0.data == [4, 0x37] }), "continuous IR plus extension mode")
    // Exercise actual packed camera bytes, including noncontiguous point slots.
    func camera(_ points: [[Int]?]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0xff, count: 22)
        bytes[0] = 0x37; bytes[1] = 0; bytes[2] = 0
        for group in 0..<2 {
            let a = points[group * 2] ?? [1023, 1023]
            let b = points[group * 2 + 1] ?? [1023, 1023]
            let offset = 6 + group * 5
            bytes[offset] = UInt8(a[0] & 255); bytes[offset + 1] = UInt8(a[1] & 255)
            bytes[offset + 2] = UInt8(((a[0] >> 8) << 4) | ((a[1] >> 8) << 6) | (b[0] >> 8) | ((b[1] >> 8) << 2))
            bytes[offset + 3] = UInt8(b[0] & 255); bytes[offset + 4] = UInt8(b[1] & 255)
        }
        return bytes
    }
    var cameras = [WiiState(), WiiState()]
    for frame in 0..<120 {
        let time = Double(frame) / 60
        for remote in 0..<2 {
            let x = 250 + frame * 2 + remote * 100
            let y = 250 + remote * 200
            let points: [[Int]?] = [frame % 3 == 1 ? nil : [x, y], nil, [x + 180, y], nil]
            _ = cameras[remote].decode(camera(points), at: time)
            let pointer = cameras[remote].tracking.pointer(at: time)
            check(pointer != nil && abs(pointer![0] - Double(x + 90) / 1023) < 0.00001, "independent moving pointers survive one-end dropouts")
            check(abs(pointer![1] - Double(y) / 767) < 0.00001, "controllers never share camera geometry")
        }
    }
    var tracker = WiiIRTracker()
    tracker.update([[0.3, 0.4]], slots: [0], at: 0)
    check(tracker.pointer(at: 0) == nil, "a lone dot cannot acquire aim")
    tracker.update([[0.3, 0.4], [0.5, 0.4]], slots: [0, 2], at: 1)
    tracker.update([[0.31, 0.4], [0.51, 0.4], [0.95, 0.95]], slots: [0, 2, 3], at: 1.01)
    check(abs(tracker.pointer(at: 1.01)![0] - 0.41) < 0.00001, "a stray reflection must not replace the acquired bar")
    tracker.update([[0.52, 0.4]], slots: [2], at: 1.02)
    check(abs(tracker.pointer(at: 1.02)![0] - 0.42) < 0.00001 && tracker.quality == "partial", "missing first endpoint retains the measured bar offset")
    check(tracker.pointer(at: 1.3) == nil, "stale camera reports expire despite bridge heartbeats")
    tracker.update([[0.52, 0.4]], slots: [2], at: 1.3)
    check(tracker.pointer(at: 1.3) == nil, "partial tracking has a bounded lifetime")
    tracker.update([[0.8, 0.6], [0.6, 0.6]], slots: [1, 3], at: 2)
    check(abs(tracker.pointer(at: 2)![0] - 0.7) < 0.00001, "full reacquisition accepts new point slots immediately")
    tracker.update([], slots: [], at: 2.01)
    check(tracker.pointer(at: 2.01) == nil, "no infrared points means no invented aim")
    tracker.update([[0.8, 0.1]], slots: [3], at: 2.02)
    check(tracker.pointer(at: 2.02) == nil, "a distant single reflection cannot recover aim")
    var stable = WiiIRTracker()
    stable.update([[0.4, 0.4], [0.5, 0.4]], slots: [0, 2], at: 3)
    stable.update([[0.505, 0.4]], slots: [0], at: 3.016)
    check(abs(stable.pointer(at: 3.016)![0] - 0.455) < 0.00001, "reassigned single-point slots must not shift aim by half a bar")
    stable.update([[0.455, 0.4]], slots: [2], at: 3.032)
    check(stable.pointer(at: 3.032) == nil, "ambiguous lone points must not choose the opposite bar endpoint")
    stable.update([[0.41, 0.4], [0.51, 0.4]], slots: [2, 0], at: 3.048)
    stable.update([[0.415, 0.4], [0.435, 0.4]], slots: [0, 1], at: 3.064)
    check(stable.quality == "partial" && abs(stable.pointer(at: 3.064)![0] - 0.465) < 0.00001, "split lights from one emitter must not become a much shorter sensor bar")
    stable.update([[0.42, 0.4], [0.95, 0.8]], slots: [0, 1], at: 3.08)
    check(stable.quality == "partial" && abs(stable.pointer(at: 3.08)![0] - 0.47) < 0.00001, "an unrelated second light must not drag the midpoint away")
    stable.update([[0.7, 0.3], [0.8, 0.3]], slots: [3, 1], at: 3.096)
    check(stable.quality == "tracked" && abs(stable.pointer(at: 3.096)![0] - 0.75) < 0.00001, "fast deliberate sweeps retain coherent bar geometry")
    stable.update([[0.2, 0.6], [0.4, 0.6]], slots: [0, 2], at: 4)
    check(stable.quality == "tracked" && abs(stable.pointer(at: 4)![0] - 0.3) < 0.00001, "full reacquisition accepts genuine distance changes after the bounded grace")
    print("Wii two-camera tracking checks: PASS")
    print("Wii protocol checks: PASS")
}
