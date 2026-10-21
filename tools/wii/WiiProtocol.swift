import Foundation

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
    var calibration = [35, 128, 228, 27, 128, 220] // min/center/max, X then Y

    // Returns true only for a complete streaming input report.
    mutating func decode(_ packet: [UInt8]) -> Bool {
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
        for offset in [6, 11] {
            let high = Int(b[offset + 2])
            let points = [
                [Int(b[offset]) | ((high & 0x30) << 4), Int(b[offset + 1]) | ((high & 0xc0) << 2)],
                [Int(b[offset + 3]) | ((high & 3) << 8), Int(b[offset + 4]) | ((high & 0x0c) << 6)]
            ]
            for point in points where point[0] < 1023 && point[1] < 768 {
                dots.append([Double(point[0]) / 1023, Double(point[1]) / 767])
            }
        }
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
        guard dots.count >= 2 else { return nil }
        var best = (0, 1), distance = -1.0
        for i in 0..<dots.count {
            for j in (i + 1)..<dots.count {
                let d = pow(dots[i][0] - dots[j][0], 2) + pow(dots[i][1] - dots[j][1], 2)
                if d > distance { best = (i, j); distance = d }
            }
        }
        return [(dots[best.0][0] + dots[best.1][0]) / 2, (dots[best.0][1] + dots[best.1][1]) / 2]
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
    print("Wii protocol checks: PASS")
}
