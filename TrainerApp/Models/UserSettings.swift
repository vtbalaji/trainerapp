import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var ftp: Int {
        didSet { UserDefaults.standard.set(ftp, forKey: "userFTP") }
    }
    
    @Published var weight: Double {
        didSet { UserDefaults.standard.set(weight, forKey: "userWeight") }
    }
    
    init() {
        let storedFTP = UserDefaults.standard.integer(forKey: "userFTP")
        self.ftp = storedFTP > 0 ? storedFTP : 200
        
        let storedWeight = UserDefaults.standard.double(forKey: "userWeight")
        self.weight = storedWeight > 0 ? storedWeight : 75.0
    }
}
