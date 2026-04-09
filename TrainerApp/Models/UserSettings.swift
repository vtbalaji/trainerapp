import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var ftp: Int {
        didSet { UserDefaults.standard.set(ftp, forKey: "userFTP") }
    }
    
    @Published var weight: Double {
        didSet { UserDefaults.standard.set(weight, forKey: "userWeight") }
    }
    
    @Published var vo2max: Double {
        didSet { UserDefaults.standard.set(vo2max, forKey: "userVO2max") }
    }
    
    @Published var vo2maxDate: Date? {
        didSet { 
            if let date = vo2maxDate {
                UserDefaults.standard.set(date, forKey: "userVO2maxDate")
            }
        }
    }
    
    init() {
        let storedFTP = UserDefaults.standard.integer(forKey: "userFTP")
        self.ftp = storedFTP > 0 ? storedFTP : 200
        
        let storedWeight = UserDefaults.standard.double(forKey: "userWeight")
        self.weight = storedWeight > 0 ? storedWeight : 75.0
        
        self.vo2max = UserDefaults.standard.double(forKey: "userVO2max")
        self.vo2maxDate = UserDefaults.standard.object(forKey: "userVO2maxDate") as? Date
    }
    
    /// Calculate VO2max from ramp test max 1-minute power
    func updateVO2max(from maxPower: Int) {
        guard weight > 0 else { return }
        // VO2max ≈ (Watts/kg) × 10.8 + 7
        let wattsPerKg = Double(maxPower) / weight
        vo2max = wattsPerKg * 10.8 + 7
        vo2maxDate = Date()
    }
}
