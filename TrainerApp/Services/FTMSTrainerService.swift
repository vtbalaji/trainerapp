import Foundation

/// FTMS-based trainer service — works with Tacx, Wahoo KICKR (FTMS mode), Elite, etc.
/// Any trainer advertising the FTMS service (0x1826) is supported.
@MainActor
final class FTMSTrainerService: TrainerProtocol {

    private let bluetooth: BluetoothManager

    var trainerData: TrainerData {
        bluetooth.latestTrainerData
    }

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
    }

    func requestControl() {
        var data = Data([FTMSConstants.opCodeRequestControl])
        bluetooth.writeControlPoint(data)
    }

    func setTargetPower(watts: Int16) {
        var data = Data([FTMSConstants.opCodeSetTargetPower])
        // Target power in watts, signed 16-bit little-endian
        var w = watts
        data.append(Data(bytes: &w, count: 2))
        bluetooth.writeControlPoint(data)
    }

    func setResistanceLevel(percent: Double) {
        var data = Data([FTMSConstants.opCodeSetTargetResistance])
        // Resistance level: unit is 0.1, so 50% = 500
        var level = Int16(percent * 10)
        data.append(Data(bytes: &level, count: 2))
        bluetooth.writeControlPoint(data)
    }

    func setSimulationParameters(
        grade: Double,
        windSpeed: Double,
        rollingResistance: Double,
        windResistance: Double
    ) {
        var data = Data([FTMSConstants.opCodeSetIndoorBikeSimulation])

        // Wind speed: signed 16-bit, resolution 0.001 m/s
        var ws = Int16(windSpeed * 1000)
        data.append(Data(bytes: &ws, count: 2))

        // Grade: signed 16-bit, resolution 0.01%
        var gr = Int16(grade * 100)
        data.append(Data(bytes: &gr, count: 2))

        // Rolling resistance coefficient: unsigned 8-bit, resolution 0.0001
        let crr = UInt8(min(255, max(0, rollingResistance * 10000)))
        data.append(crr)

        // Wind resistance coefficient: unsigned 8-bit, resolution 0.01 kg/m
        let cw = UInt8(min(255, max(0, windResistance * 100)))
        data.append(cw)

        bluetooth.writeControlPoint(data)
    }

    func start() {
        let data = Data([FTMSConstants.opCodeStartOrResume])
        bluetooth.writeControlPoint(data)
    }

    func stop() {
        var data = Data([FTMSConstants.opCodeStopOrPause])
        data.append(0x01) // 0x01 = stop, 0x02 = pause
        bluetooth.writeControlPoint(data)
    }

    func reset() {
        let data = Data([FTMSConstants.opCodeReset])
        bluetooth.writeControlPoint(data)
    }
}
