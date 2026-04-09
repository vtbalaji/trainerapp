import Foundation
import CoreBluetooth
import Combine

/// Discovered BLE peripheral with its advertised name and signal strength
struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    let advertisedServices: [CBUUID]

    /// Best guess at what this device is
    var deviceType: DeviceType {
        let lowerName = name.lowercased()
        
        // Trainer detection
        if advertisedServices.contains(FTMSConstants.ftmsServiceUUID)
            || advertisedServices.contains(FTMSConstants.tacxFECServiceUUID)
            || lowerName.contains("tacx")
            || lowerName.contains("kickr")
            || lowerName.contains("flux")
            || lowerName.contains("neo")
            || lowerName.contains("elite")
            || lowerName.contains("saris")
            || lowerName.contains("bkool")
            || lowerName.contains("wahoo snap")
            || lowerName.contains("direto")
            || lowerName.contains("drivo")
            || lowerName.contains("qubo")
            || lowerName.contains("hammer")
            || lowerName.contains("magnus")
            || lowerName.contains("trainer") {
            return .trainer
        }
        
        // HR monitor detection
        if advertisedServices.contains(FTMSConstants.heartRateServiceUUID)
            || lowerName.contains("hrm")
            || lowerName.contains("heart")
            || lowerName.contains("polar")
            || lowerName.contains("garmin")
            || lowerName.contains("wahoo tickr")
            || lowerName.contains("coospo")
            || lowerName.contains("magene")
            || lowerName.contains("moofit")
            || lowerName.contains("coros")
            || lowerName.contains("suunto")
            || lowerName.contains("scosche")
            || lowerName.contains("h10")
            || lowerName.contains("h9")
            || lowerName.contains("oh1")
            || lowerName.contains("verity") {
            return .heartRate
        }
        return .unknown
    }

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

enum DeviceType: String, Codable {
    case trainer
    case heartRate
    case unknown
}

/// Connection state
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case ready
}

/// Manages CoreBluetooth with multi-device support (trainer + HR)
@MainActor
final class BluetoothManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var statusMessage: String = "Ready to scan"
    @Published var debugLog: [String] = []

    // Trainer state
    @Published var trainerState: ConnectionState = .disconnected
    @Published var latestTrainerData: TrainerData = TrainerData()
    @Published var scanAllDevices: Bool = true

    enum TrainerProtocolType {
        case ftms
        case tacxFEC
        case unknown
    }
    @Published var detectedProtocol: TrainerProtocolType = .unknown

    // Heart Rate state
    @Published var hrState: ConnectionState = .disconnected
    @Published var currentHeartRate: UInt8 = 0
    @Published var hrDeviceName: String = ""

    // MARK: - Peripheral tracking

    private var centralManager: CBCentralManager!
    private var trainerPeripheral: CBPeripheral?
    private var hrPeripheral: CBPeripheral?
    private var controlPointCharacteristic: CBCharacteristic?
    private var tacxWriteCharacteristic: CBCharacteristic?

    // MARK: - Computed

    var trainerPeripheralID: UUID? { trainerPeripheral?.identifier }
    var trainerPeripheralName: String? { trainerPeripheral?.name }
    var hrPeripheralID: UUID? { hrPeripheral?.identifier }

    // MARK: - Logging

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        print(entry)
        debugLog.append(entry)
        if debugLog.count > 200 { debugLog.removeFirst() }
    }

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            statusMessage = "Bluetooth is not available"
            log("Scan failed: BT state = \(centralManager.state.rawValue)")
            return
        }
        centralManager.stopScan()
        discoveredDevices.removeAll()
        debugLog.removeAll()
        isScanning = true

        if scanAllDevices {
            statusMessage = "Scanning all BLE devices..."
            log("Starting broad scan (no service filter)")
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        } else {
            statusMessage = "Scanning for trainers & HR monitors..."
            log("Scanning for FTMS + Tacx FE-C + HR services")
            centralManager.scanForPeripherals(
                withServices: [
                    FTMSConstants.ftmsServiceUUID,
                    FTMSConstants.tacxFECServiceUUID,
                    FTMSConstants.heartRateServiceUUID
                ],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }

        Task {
            try? await Task.sleep(for: .seconds(15))
            if isScanning { stopScanning() }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = discoveredDevices.isEmpty
            ? "No devices found"
            : "Scan complete — \(discoveredDevices.count) device(s)"
    }

    // MARK: - Trainer Connection

    func connectTrainer(to device: DiscoveredDevice) {
        if isScanning { stopScanning() }
        trainerState = .connecting
        statusMessage = "Connecting trainer: \(device.name)..."
        log("Connecting trainer: \(device.name) (ID: \(device.id))")
        trainerPeripheral = device.peripheral
        centralManager.connect(device.peripheral, options: nil)
        startTimeout(for: .trainer, name: device.name)
    }

    func reconnectTrainer(to id: UUID, name: String) {
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [id])
        guard let peripheral = peripherals.first else {
            log("Trainer \(name) not found — try scanning")
            statusMessage = "Trainer not found — try scanning"
            return
        }
        trainerState = .connecting
        statusMessage = "Reconnecting trainer: \(name)..."
        log("Reconnecting trainer: \(name) (ID: \(id))")
        trainerPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        startTimeout(for: .trainer, name: name)
    }
    
    func autoReconnectSavedDevices() {
        let store = SavedTrainerStore.shared
        
        // Auto-reconnect saved trainer
        if let trainer = store.savedTrainers.first, trainerState == .disconnected {
            log("Auto-reconnecting trainer: \(trainer.displayName)")
            reconnectTrainer(to: trainer.id, name: trainer.displayName)
        }
        
        // Auto-reconnect saved HR monitor
        if let hr = store.savedHRMonitors.first, hrState == .disconnected {
            log("Auto-reconnecting HR: \(hr.displayName)")
            reconnectHR(to: hr.id, name: hr.displayName)
        }
    }

    func disconnectTrainer() {
        if let peripheral = trainerPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        trainerPeripheral = nil
        controlPointCharacteristic = nil
        tacxWriteCharacteristic = nil
        detectedProtocol = .unknown
        trainerState = .disconnected
        log("Trainer disconnected")
        updateStatusMessage()
    }

    // MARK: - HR Connection

    func connectHR(to device: DiscoveredDevice) {
        if isScanning { stopScanning() }
        hrState = .connecting
        hrDeviceName = device.name
        statusMessage = "Connecting HR: \(device.name)..."
        log("Connecting HR: \(device.name) (ID: \(device.id))")
        hrPeripheral = device.peripheral
        centralManager.connect(device.peripheral, options: nil)
        startTimeout(for: .heartRate, name: device.name)
    }

    func reconnectHR(to id: UUID, name: String) {
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [id])
        guard let peripheral = peripherals.first else {
            log("HR \(name) not found — try scanning")
            statusMessage = "HR monitor not found — try scanning"
            return
        }
        hrState = .connecting
        hrDeviceName = name
        statusMessage = "Reconnecting HR: \(name)..."
        log("Reconnecting HR: \(name) (ID: \(id))")
        hrPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        startTimeout(for: .heartRate, name: name)
    }

    func disconnectHR() {
        if let peripheral = hrPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        hrPeripheral = nil
        hrState = .disconnected
        currentHeartRate = 0
        hrDeviceName = ""
        log("HR disconnected")
        updateStatusMessage()
    }

    // MARK: - Write Commands

    func writeControlPoint(_ data: Data) {
        guard let peripheral = trainerPeripheral,
              let characteristic = controlPointCharacteristic else {
            statusMessage = "Trainer not connected"
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    func writeTacxFEC(_ data: Data) {
        guard let peripheral = trainerPeripheral,
              let characteristic = tacxWriteCharacteristic else {
            statusMessage = "Tacx write not available"
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        log("Sent FE-C: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }

    // MARK: - Helpers

    private func startTimeout(for type: DeviceType, name: String) {
        Task {
            try? await Task.sleep(for: .seconds(10))
            switch type {
            case .trainer:
                if trainerState == .connecting {
                    log("Trainer connection timeout")
                    disconnectTrainer()
                    statusMessage = "Trainer connection timed out"
                }
            case .heartRate:
                if hrState == .connecting {
                    log("HR connection timeout")
                    disconnectHR()
                    statusMessage = "HR connection timed out"
                }
            case .unknown:
                break
            }
        }
    }

    private func updateStatusMessage() {
        var parts: [String] = []
        if trainerState == .ready {
            parts.append("Trainer: \(trainerPeripheralName ?? "connected")")
        }
        if hrState == .ready {
            parts.append("HR: \(hrDeviceName)")
        }
        if parts.isEmpty {
            statusMessage = "No devices connected"
        } else {
            statusMessage = parts.joined(separator: " | ")
        }
    }

    /// Identify which peripheral this is (trainer or HR)
    private func peripheralRole(_ peripheral: CBPeripheral) -> DeviceType {
        if peripheral.identifier == trainerPeripheral?.identifier { return .trainer }
        if peripheral.identifier == hrPeripheral?.identifier { return .heartRate }
        return .unknown
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            log("BT state: \(central.state.rawValue)")
            switch central.state {
            case .poweredOn:
                statusMessage = "Bluetooth ready"
                autoReconnectSavedDevices()
            case .poweredOff:
                statusMessage = "Bluetooth is turned off"
                trainerState = .disconnected
                hrState = .disconnected
            case .unauthorized:
                statusMessage = "Bluetooth permission denied — check System Settings"
            case .unsupported:
                statusMessage = "BLE not supported"
            default:
                statusMessage = "Bluetooth unavailable"
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown Device"
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []

        let device = DiscoveredDevice(
            id: peripheral.identifier,
            peripheral: peripheral,
            name: name,
            rssi: RSSI.intValue,
            advertisedServices: serviceUUIDs
        )

        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
                let serviceStr = serviceUUIDs.map { $0.uuidString }.joined(separator: ", ")
                log("Found: \(name) | RSSI: \(RSSI) | Services: [\(serviceStr)] | Type: \(device.deviceType)")
                statusMessage = "Found \(discoveredDevices.count) device(s)..."
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            let role = peripheralRole(peripheral)
            log("Connected \(role.rawValue): \(peripheral.name ?? "unknown")")

            switch role {
            case .trainer:
                trainerState = .connected
                statusMessage = "Trainer connected — discovering services..."
            case .heartRate:
                hrState = .connected
                statusMessage = "HR connected — discovering services..."
            case .unknown:
                log("Connected unknown peripheral — treating as trainer")
                trainerPeripheral = peripheral
                trainerState = .connected
            }

            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let role = peripheralRole(peripheral)
            let msg = error?.localizedDescription ?? "unknown"
            log("Failed to connect \(role.rawValue): \(msg)")
            switch role {
            case .trainer: trainerState = .disconnected
            case .heartRate: hrState = .disconnected
            case .unknown: break
            }
            statusMessage = "Connection failed: \(msg)"
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let role = peripheralRole(peripheral)
            let msg = error?.localizedDescription ?? ""
            log("Disconnected \(role.rawValue)\(msg.isEmpty ? "" : ": \(msg)")")

            switch role {
            case .trainer:
                trainerPeripheral = nil
                controlPointCharacteristic = nil
                tacxWriteCharacteristic = nil
                detectedProtocol = .unknown
                trainerState = .disconnected
            case .heartRate:
                hrPeripheral = nil
                hrState = .disconnected
                currentHeartRate = 0
            case .unknown:
                break
            }
            updateStatusMessage()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                log("Service discovery error: \(error.localizedDescription)")
                return
            }
            guard let services = peripheral.services, !services.isEmpty else {
                log("No services on \(peripheral.name ?? "unknown")")
                return
            }

            let role = peripheralRole(peripheral)
            log("\(role.rawValue) has \(services.count) service(s):")

            var foundFTMS = false
            var foundTacxFEC = false
            var foundHR = false

            for service in services {
                log("  Service: \(service.uuid.uuidString)")
                if service.uuid == FTMSConstants.ftmsServiceUUID { foundFTMS = true }
                if service.uuid == FTMSConstants.tacxFECServiceUUID { foundTacxFEC = true }
                if service.uuid == FTMSConstants.heartRateServiceUUID { foundHR = true }
            }

            // For trainer peripheral
            if role == .trainer || role == .unknown {
                if foundFTMS {
                    detectedProtocol = .ftms
                    log("Using FTMS protocol")
                    for service in services where service.uuid == FTMSConstants.ftmsServiceUUID {
                        peripheral.discoverCharacteristics(nil, for: service)
                    }
                } else if foundTacxFEC {
                    detectedProtocol = .tacxFEC
                    log("Using Tacx FE-C protocol")
                    for service in services where service.uuid == FTMSConstants.tacxFECServiceUUID {
                        peripheral.discoverCharacteristics(nil, for: service)
                    }
                } else {
                    detectedProtocol = .unknown
                    log("No known trainer protocol — discovering all")
                    for service in services {
                        peripheral.discoverCharacteristics(nil, for: service)
                    }
                }
                // Also discover HR if trainer has it built in
                if foundHR {
                    for service in services where service.uuid == FTMSConstants.heartRateServiceUUID {
                        peripheral.discoverCharacteristics(nil, for: service)
                    }
                }
            }

            // For HR peripheral
            if role == .heartRate {
                if foundHR {
                    for service in services where service.uuid == FTMSConstants.heartRateServiceUUID {
                        peripheral.discoverCharacteristics(nil, for: service)
                    }
                } else {
                    // Discover all to find HR-like characteristics
                    for service in services {
                        peripheral.discoverCharacteristics(nil, for: service)
                    }
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error {
                log("Char error \(service.uuid): \(error.localizedDescription)")
                return
            }
            guard let characteristics = service.characteristics else { return }

            let role = peripheralRole(peripheral)
            log("Service \(service.uuid.uuidString) has \(characteristics.count) char(s):")
            for c in characteristics {
                let props = c.properties
                let p = [
                    props.contains(.read) ? "R" : "",
                    props.contains(.write) ? "W" : "",
                    props.contains(.notify) ? "N" : "",
                    props.contains(.indicate) ? "I" : "",
                ].filter { !$0.isEmpty }.joined(separator: ",")
                log("  Char: \(c.uuid.uuidString) [\(p)]")
            }

            // FTMS service
            if service.uuid == FTMSConstants.ftmsServiceUUID {
                for c in characteristics {
                    switch c.uuid {
                    case FTMSConstants.indoorBikeDataUUID:
                        peripheral.setNotifyValue(true, for: c)
                        log("Subscribed: Indoor Bike Data")
                    case FTMSConstants.fitnessMachineControlPointUUID:
                        controlPointCharacteristic = c
                        peripheral.setNotifyValue(true, for: c)
                        peripheral.writeValue(Data([FTMSConstants.opCodeRequestControl]), for: c, type: .withResponse)
                        log("Requested trainer control")
                    case FTMSConstants.fitnessMachineStatusUUID:
                        peripheral.setNotifyValue(true, for: c)
                    default: break
                    }
                }
                trainerState = .ready
                statusMessage = "Trainer ready (FTMS)"
                log("Trainer ready via FTMS!")
                updateStatusMessage()
                return
            }

            // Tacx FE-C service
            if service.uuid == FTMSConstants.tacxFECServiceUUID {
                for c in characteristics {
                    if c.uuid == FTMSConstants.tacxFECNotifyUUID {
                        peripheral.setNotifyValue(true, for: c)
                        log("Subscribed: Tacx FE-C notify")
                    } else if c.uuid == FTMSConstants.tacxFECWriteUUID {
                        tacxWriteCharacteristic = c
                        log("Found: Tacx FE-C write")
                    } else if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                        peripheral.setNotifyValue(true, for: c)
                        log("Also subscribed: \(c.uuid.uuidString)")
                    }
                }
                trainerState = .ready
                log("Trainer ready via Tacx FE-C!")
                updateStatusMessage()
                return
            }

            // Heart Rate service
            if service.uuid == FTMSConstants.heartRateServiceUUID {
                for c in characteristics {
                    if c.uuid == FTMSConstants.heartRateMeasurementUUID {
                        peripheral.setNotifyValue(true, for: c)
                        log("Subscribed: Heart Rate Measurement")
                    }
                }
                if role == .heartRate {
                    hrState = .ready
                    log("HR monitor ready!")
                } else {
                    log("Built-in HR on trainer ready")
                }
                updateStatusMessage()
                return
            }

            // Unknown service — subscribe to all notify chars
            for c in characteristics {
                if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: c)
                    log("Auto-sub: \(c.uuid.uuidString)")
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            Task { @MainActor in
                log("Read error \(characteristic.uuid): \(error.localizedDescription)")
            }
            return
        }
        guard let data = characteristic.value else { return }

        Task { @MainActor in
            switch characteristic.uuid {

            // FTMS Indoor Bike Data
            case FTMSConstants.indoorBikeDataUUID:
                let parsed = TrainerData.parse(from: data)
                latestTrainerData = parsed
                if parsed.instantaneousPower != 0 || debugLog.count < 30 {
                    log("FTMS: \(parsed.instantaneousPower)W \(String(format: "%.0f", parsed.instantaneousCadence))rpm \(String(format: "%.1f", parsed.instantaneousSpeed))km/h")
                }

            // FTMS Control Point response
            case FTMSConstants.fitnessMachineControlPointUUID:
                let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                if data.count >= 3 {
                    log("Control response: \(hex) — \(data[2] == 0x01 ? "OK" : "FAIL(\(data[2]))")")
                }

            // FTMS Status
            case FTMSConstants.fitnessMachineStatusUUID:
                let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                log("Status: \(hex)")

            // Tacx FE-C data
            case FTMSConstants.tacxFECNotifyUUID:
                let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                let parsed = TrainerData.parseFEC(from: data, previous: latestTrainerData)
                latestTrainerData = parsed
                let page = data.count > 0 ? String(format: "0x%02X", data[data.count >= 13 ? 4 : 0]) : "?"
                log("FE-C \(page): \(parsed.instantaneousPower)W \(String(format: "%.0f", parsed.instantaneousCadence))rpm [\(hex)]")

            // Heart Rate Measurement
            case FTMSConstants.heartRateMeasurementUUID:
                let hr = parseHeartRate(data)
                currentHeartRate = hr
                // Also update trainerData so dashboard shows it
                latestTrainerData.heartRate = hr
                log("HR: \(hr) bpm")

            default:
                let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                log("DATA \(characteristic.uuid.uuidString) [\(data.count)B]: \(hex)")
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error {
                log("Write error \(characteristic.uuid): \(error.localizedDescription)")
            } else {
                log("Write OK: \(characteristic.uuid)")
            }
        }
    }

    // MARK: - Heart Rate Parsing

    /// Parse BLE Heart Rate Measurement characteristic (0x2A37)
    @MainActor
    private func parseHeartRate(_ data: Data) -> UInt8 {
        guard data.count >= 2 else { return 0 }
        let flags = data[0]
        // Bit 0: 0 = HR is UInt8 at byte 1, 1 = HR is UInt16 at bytes 1-2
        if flags & 0x01 == 0 {
            return data[1]
        } else if data.count >= 3 {
            let hr16: UInt16 = data.readLE(at: 1)
            return UInt8(min(255, hr16))
        }
        return 0
    }
}
