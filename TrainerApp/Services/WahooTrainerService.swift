import Foundation

/// Wahoo KICKR proprietary trainer service — sends commands via Cycling Power Service
/// with proprietary control characteristic A026E005.
/// Supports KICKR, KICKR Core, KICKR Snap, KICKR Climb.
@MainActor
final class WahooTrainerService: TrainerProtocol {

    private let bluetooth: BluetoothManager

    var trainerData: TrainerData {
        bluetooth.latestTrainerData
    }

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func requestControl() {
        // Wahoo doesn't require explicit control request — write directly
        bluetooth.log("Wahoo: control always available")
    }

    func setTargetPower(watts: Int16) {
        // Wahoo ERG: [0x42, power_lo, power_hi] — sint16 little-endian
        var data = Data(count: 3)
        data[0] = 0x42
        let w = UInt16(bitPattern: max(0, watts))
        data[1] = UInt8(w & 0xFF)
        data[2] = UInt8((w >> 8) & 0xFF)
        bluetooth.writeWahooControl(data)
        bluetooth.log("Wahoo: Set target power \(watts)W")
    }

    func setResistanceLevel(percent: Double) {
        // Wahoo resistance: [0x40, level_lo, level_hi]
        // Level range 0-16383 maps to 0-100%
        let level = UInt16(min(16383, max(0, percent / 100.0 * 16383)))
        var data = Data(count: 3)
        data[0] = 0x40
        data[1] = UInt8(level & 0xFF)
        data[2] = UInt8((level >> 8) & 0xFF)
        bluetooth.writeWahooControl(data)
        bluetooth.log("Wahoo: Set resistance \(percent)%")
    }

    func setSimulationParameters(
        grade: Double,
        windSpeed: Double,
        rollingResistance: Double,
        windResistance: Double
    ) {
        // Wahoo gradient: [0x46, value_lo, value_hi]
        // value = (gradient/100 + 1.0) * 32768
        let value = UInt16(clamping: Int((grade / 100.0 + 1.0) * 32768.0))
        var data = Data(count: 3)
        data[0] = 0x46
        data[1] = UInt8(value & 0xFF)
        data[2] = UInt8((value >> 8) & 0xFF)
        bluetooth.writeWahooControl(data)
        bluetooth.log("Wahoo: Set grade \(String(format: "%.1f", grade))%")
    }

    func start() {
        bluetooth.log("Wahoo: Trainer always running")
    }

    func stop() {
        setTargetPower(watts: 0)
    }

    func reset() {
        setTargetPower(watts: 0)
    }
}
