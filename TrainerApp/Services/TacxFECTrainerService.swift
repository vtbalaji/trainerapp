import Foundation

/// Tacx FE-C over BLE trainer service — sends ANT+ FE-C commands wrapped for BLE
@MainActor
final class TacxFECTrainerService: TrainerProtocol {

    private let bluetooth: BluetoothManager

    var trainerData: TrainerData {
        bluetooth.latestTrainerData
    }

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func requestControl() {
        // FE-C doesn't have an explicit control request — it's always controllable
        bluetooth.log("FE-C: control always available")
    }

    func setTargetPower(watts: Int16) {
        // ANT+ FE-C Page 49 (0x31): Target Power
        // Format: [sync(1)] [msg_len(1)] [msg_type(1)] [channel(1)] [page(1)] [data(7)] [checksum(1)]
        // BLE simplified: just the 9-byte data payload
        var data = Data(repeating: 0, count: 13)

        // ANT+ message wrapper for BLE
        data[0] = 0xA4  // Sync byte
        data[1] = 0x09  // Message length (9 bytes payload)
        data[2] = 0x4E  // Message type: Acknowledged data
        data[3] = 0x05  // Channel number (5 = typical for FE-C)

        // Page 49 (0x31): Target Power
        data[4] = 0x31  // Data page 49
        data[5] = 0xFF  // Reserved
        data[6] = 0xFF  // Reserved
        data[7] = 0xFF  // Reserved
        data[8] = 0xFF  // Reserved
        data[9] = 0xFF  // Reserved

        // Target power in 0.25W resolution (little-endian)
        let powerQuarters = UInt16(max(0, watts)) * 4
        data[10] = UInt8(powerQuarters & 0xFF)
        data[11] = UInt8((powerQuarters >> 8) & 0xFF)

        // Checksum: XOR of all bytes from sync to last data byte
        var checksum: UInt8 = 0
        for i in 0..<12 {
            checksum ^= data[i]
        }
        data[12] = checksum

        bluetooth.writeTacxFEC(data)
        bluetooth.log("FE-C: Set target power \(watts)W")
    }

    func setResistanceLevel(percent: Double) {
        // ANT+ FE-C Page 48 (0x30): Basic Resistance
        var data = Data(repeating: 0, count: 13)

        data[0] = 0xA4  // Sync
        data[1] = 0x09  // Length
        data[2] = 0x4E  // Acknowledged data
        data[3] = 0x05  // Channel

        data[4] = 0x30  // Data page 48: Basic Resistance
        data[5] = 0xFF  // Reserved
        data[6] = 0xFF
        data[7] = 0xFF
        data[8] = 0xFF
        data[9] = 0xFF
        data[10] = 0xFF

        // Resistance: 0-200 (0.5% resolution, so 100% = 200)
        let resistance = UInt8(min(200, max(0, percent * 2.0)))
        data[11] = resistance

        var checksum: UInt8 = 0
        for i in 0..<12 { checksum ^= data[i] }
        data[12] = checksum

        bluetooth.writeTacxFEC(data)
        bluetooth.log("FE-C: Set resistance \(percent)%")
    }

    func setSimulationParameters(
        grade: Double,
        windSpeed: Double,
        rollingResistance: Double,
        windResistance: Double
    ) {
        // ANT+ FE-C Page 51 (0x33): Track Resistance (Simulation)
        var data = Data(repeating: 0, count: 13)

        data[0] = 0xA4  // Sync
        data[1] = 0x09  // Length
        data[2] = 0x4E  // Acknowledged data
        data[3] = 0x05  // Channel

        data[4] = 0x33  // Data page 51: Track Resistance
        data[5] = 0xFF  // Reserved
        data[6] = 0xFF
        data[7] = 0xFF
        data[8] = 0xFF

        // Grade: signed 16-bit, 0.01% resolution, offset by 200% (so 0% = 0x4E20)
        let gradeRaw = Int16((grade + 200.0) * 100.0)
        data[9] = UInt8(UInt16(bitPattern: gradeRaw) & 0xFF)
        data[10] = UInt8((UInt16(bitPattern: gradeRaw) >> 8) & 0xFF)

        // Rolling resistance coefficient: 5x10^-5 resolution
        let crr = UInt8(min(255, max(0, rollingResistance / 0.00005)))
        data[11] = crr

        var checksum: UInt8 = 0
        for i in 0..<12 { checksum ^= data[i] }
        data[12] = checksum

        bluetooth.writeTacxFEC(data)
        bluetooth.log("FE-C: Set grade \(String(format: "%.1f", grade))%, CRR \(rollingResistance)")
    }

    func start() {
        bluetooth.log("FE-C: Trainer always running")
    }

    func stop() {
        setTargetPower(watts: 0)
    }

    func reset() {
        setTargetPower(watts: 0)
    }
}
