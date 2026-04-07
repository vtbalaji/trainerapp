import CoreBluetooth

/// FTMS (Fitness Machine Service) BLE UUIDs and helpers
enum FTMSConstants {
    // MARK: - Service UUIDs
    static let ftmsServiceUUID = CBUUID(string: "1826")

    // MARK: - Tacx Proprietary (ANT+ FE-C over BLE)
    /// Tacx Neo v1/v2 proprietary service (FE-C over BLE bridge)
    static let tacxFECServiceUUID = CBUUID(string: "6E40FEC1-B5A3-F393-E0A9-E50E24DCCA9E")
    /// Notify characteristic — receive FE-C data from trainer
    static let tacxFECNotifyUUID = CBUUID(string: "6E40FEC2-B5A3-F393-E0A9-E50E24DCCA9E")
    /// Write characteristic — send FE-C commands to trainer
    static let tacxFECWriteUUID = CBUUID(string: "6E40FEC3-B5A3-F393-E0A9-E50E24DCCA9E")

    // MARK: - Characteristic UUIDs
    /// Notifies: instantaneous speed, cadence, power, etc.
    static let indoorBikeDataUUID = CBUUID(string: "2AD2")
    /// Write: control resistance, target power, simulation params
    static let fitnessMachineControlPointUUID = CBUUID(string: "2AD9")
    /// Read: supported resistance/power ranges
    static let supportedResistanceLevelRangeUUID = CBUUID(string: "2AD6")
    /// Read: supported power range
    static let supportedPowerRangeUUID = CBUUID(string: "2AD8")
    /// Notify: status changes (reset, stop, etc.)
    static let fitnessMachineStatusUUID = CBUUID(string: "2ADA")
    /// Read: which features the trainer supports
    static let fitnessMachineFeatureUUID = CBUUID(string: "2ACC")

    // MARK: - Heart Rate Service (standard BLE)
    static let heartRateServiceUUID = CBUUID(string: "180D")
    /// Heart Rate Measurement characteristic — notify
    static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    /// Body Sensor Location — read
    static let bodySensorLocationUUID = CBUUID(string: "2A38")

    // MARK: - Control Point Op Codes
    static let opCodeRequestControl: UInt8 = 0x00
    static let opCodeReset: UInt8 = 0x01
    static let opCodeSetTargetResistance: UInt8 = 0x04
    static let opCodeSetTargetPower: UInt8 = 0x05
    static let opCodeStartOrResume: UInt8 = 0x07
    static let opCodeStopOrPause: UInt8 = 0x08
    static let opCodeSetIndoorBikeSimulation: UInt8 = 0x11

    /// All characteristics we want to discover
    static let characteristicUUIDs: [CBUUID] = [
        indoorBikeDataUUID,
        fitnessMachineControlPointUUID,
        supportedResistanceLevelRangeUUID,
        supportedPowerRangeUUID,
        fitnessMachineStatusUUID,
        fitnessMachineFeatureUUID
    ]
}
