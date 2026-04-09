import Foundation

/// A device that has been previously paired and saved for quick reconnection
struct SavedDevice: Codable, Identifiable, Equatable {
    let id: UUID              // CBPeripheral identifier
    var name: String
    var deviceType: DeviceType // trainer or heartRate
    var protocol_: String     // "ftms", "tacxFEC", "heartRate"
    var lastConnected: Date
    var customName: String?   // user-assigned nickname

    var displayName: String {
        customName ?? name
    }

    enum CodingKeys: String, CodingKey {
        case id, name, deviceType, protocol_, lastConnected, customName
    }
}

/// Manages persistence of saved devices using UserDefaults
@MainActor
final class SavedTrainerStore: ObservableObject {
    static let shared = SavedTrainerStore()
    
    @Published var savedDevices: [SavedDevice] = []

    private let key = "savedDevices"

    init() {
        load()
    }

    var savedTrainers: [SavedDevice] {
        savedDevices.filter { $0.deviceType == .trainer }
    }

    var savedHRMonitors: [SavedDevice] {
        savedDevices.filter { $0.deviceType == .heartRate }
    }

    func save(_ device: SavedDevice) {
        if let index = savedDevices.firstIndex(where: { $0.id == device.id }) {
            savedDevices[index].lastConnected = device.lastConnected
            savedDevices[index].name = device.name
            savedDevices[index].deviceType = device.deviceType
            savedDevices[index].protocol_ = device.protocol_
            if let customName = device.customName {
                savedDevices[index].customName = customName
            }
        } else {
            savedDevices.append(device)
        }
        persist()
    }

    func remove(_ device: SavedDevice) {
        savedDevices.removeAll { $0.id == device.id }
        persist()
    }

    func rename(_ device: SavedDevice, to newName: String) {
        if let index = savedDevices.firstIndex(where: { $0.id == device.id }) {
            savedDevices[index].customName = newName.isEmpty ? nil : newName
            persist()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedDevice].self, from: data) else {
            return
        }
        savedDevices = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
