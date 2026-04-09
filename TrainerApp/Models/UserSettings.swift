import Foundation

enum Gender: String, CaseIterable {
    case male = "Male"
    case female = "Female"
}

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var ftp: Int {
        didSet { UserDefaults.standard.set(ftp, forKey: "userFTP") }
    }
    
    @Published var weight: Double {
        didSet { UserDefaults.standard.set(weight, forKey: "userWeight") }
    }
    
    @Published var height: Double {
        didSet { UserDefaults.standard.set(height, forKey: "userHeight") }
    }
    
    @Published var age: Int {
        didSet { UserDefaults.standard.set(age, forKey: "userAge") }
    }
    
    @Published var gender: Gender {
        didSet { UserDefaults.standard.set(gender.rawValue, forKey: "userGender") }
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
        
        let storedHeight = UserDefaults.standard.double(forKey: "userHeight")
        self.height = storedHeight > 0 ? storedHeight : 170.0
        
        let storedAge = UserDefaults.standard.integer(forKey: "userAge")
        self.age = storedAge > 0 ? storedAge : 30
        
        let storedGender = UserDefaults.standard.string(forKey: "userGender") ?? "Male"
        self.gender = Gender(rawValue: storedGender) ?? .male
        
        self.vo2max = UserDefaults.standard.double(forKey: "userVO2max")
        self.vo2maxDate = UserDefaults.standard.object(forKey: "userVO2maxDate") as? Date
    }
    
    /// Calculate VO2max from ramp test max 1-minute power
    func updateVO2max(from maxPower: Int) {
        guard weight > 0 else { return }
        let wattsPerKg = Double(maxPower) / weight
        vo2max = wattsPerKg * 10.8 + 7
        vo2maxDate = Date()
    }
}
