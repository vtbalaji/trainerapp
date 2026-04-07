import Foundation
import WebKit
import SwiftUI

@MainActor
class StravaService: NSObject, ObservableObject {
    static let shared = StravaService()
    
    private let clientId = Config.stravaClientId
    private let clientSecret = Config.stravaClientSecret
    private let redirectUri = "http://localhost/exchange_token"
    
    @Published var isConnected = false
    @Published var athleteName: String = ""
    @Published var isUploading = false
    @Published var lastError: String?
    @Published var showAuthSheet = false
    
    var authURL: URL? {
        let scope = "activity:write,read"
        let urlString = "https://www.strava.com/oauth/authorize?client_id=\(clientId)&redirect_uri=\(redirectUri)&response_type=code&scope=\(scope)"
        return URL(string: urlString)
    }
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "stravaAccessToken") }
        set { UserDefaults.standard.set(newValue, forKey: "stravaAccessToken") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "stravaRefreshToken") }
        set { UserDefaults.standard.set(newValue, forKey: "stravaRefreshToken") }
    }
    
    private var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: "stravaTokenExpiry") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "stravaTokenExpiry") }
    }
    
    override init() {
        super.init()
        isConnected = accessToken != nil
        if isConnected {
            athleteName = UserDefaults.standard.string(forKey: "stravaAthleteName") ?? ""
        }
    }
    
    // MARK: - OAuth
    
    func connect() {
        showAuthSheet = true
    }
    
    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            lastError = "No authorization code received"
            return
        }
        
        await exchangeCodeForToken(code: code)
        showAuthSheet = false
    }
    
    private func exchangeCodeForToken(code: String) async {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(clientId)&client_secret=\(clientSecret)&code=\(code)&grant_type=authorization_code"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
            
            accessToken = response.access_token
            refreshToken = response.refresh_token
            tokenExpiry = Date(timeIntervalSince1970: TimeInterval(response.expires_at))
            athleteName = "\(response.athlete.firstname) \(response.athlete.lastname)"
            UserDefaults.standard.set(athleteName, forKey: "stravaAthleteName")
            isConnected = true
            lastError = nil
        } catch {
            lastError = "Token exchange failed: \(error.localizedDescription)"
        }
    }
    
    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken else { return false }
        
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(clientId)&client_secret=\(clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(StravaRefreshResponse.self, from: data)
            
            self.accessToken = response.access_token
            self.refreshToken = response.refresh_token
            self.tokenExpiry = Date(timeIntervalSince1970: TimeInterval(response.expires_at))
            return true
        } catch {
            return false
        }
    }
    
    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        athleteName = ""
        UserDefaults.standard.removeObject(forKey: "stravaAthleteName")
        isConnected = false
    }
    
    // MARK: - Upload
    
    func uploadWorkout(_ session: WorkoutSession) async -> Bool {
        // Check token expiry
        if let expiry = tokenExpiry, expiry < Date() {
            let refreshed = await refreshAccessToken()
            if !refreshed {
                lastError = "Session expired. Please reconnect to Strava."
                isConnected = false
                return false
            }
        }
        
        guard let token = accessToken else {
            lastError = "Not connected to Strava"
            return false
        }
        
        isUploading = true
        defer { isUploading = false }
        
        // Generate TCX file
        let tcxData = generateTCX(for: session)
        
        // Upload to Strava
        let url = URL(string: "https://www.strava.com/api/v3/uploads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Activity type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"activity_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("virtualride\r\n".data(using: .utf8)!)
        
        // Data type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("tcx\r\n".data(using: .utf8)!)
        
        // Name
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(session.planName)\r\n".data(using: .utf8)!)
        
        // File
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"workout.tcx\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/xml\r\n\r\n".data(using: .utf8)!)
        body.append(tcxData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    lastError = nil
                    return true
                } else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                    lastError = "Upload failed: \(errorMsg)"
                    return false
                }
            }
            return false
        } catch {
            lastError = "Upload failed: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - TCX Generation
    
    private func generateTCX(for session: WorkoutSession) -> Data {
        let dateFormatter = ISO8601DateFormatter()
        let startTime = dateFormatter.string(from: session.date)
        
        var tcx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Biking">
              <Id>\(startTime)</Id>
              <Lap StartTime="\(startTime)">
                <TotalTimeSeconds>\(session.durationSeconds)</TotalTimeSeconds>
                <DistanceMeters>0</DistanceMeters>
                <Calories>0</Calories>
                <AverageHeartRateBpm><Value>\(session.avgHeartRate)</Value></AverageHeartRateBpm>
                <MaximumHeartRateBpm><Value>\(session.maxHeartRate)</Value></MaximumHeartRateBpm>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>
                <Track>
        """
        
        // Generate trackpoints from detailed data if available
        if let details = session.detailedData, !details.isEmpty {
            for (index, point) in details.enumerated() {
                let pointTime = session.date.addingTimeInterval(TimeInterval(index))
                let pointTimeStr = dateFormatter.string(from: pointTime)
                tcx += """
                
                          <Trackpoint>
                            <Time>\(pointTimeStr)</Time>
                            <HeartRateBpm><Value>\(point.heartRate)</Value></HeartRateBpm>
                            <Cadence>\(point.cadence)</Cadence>
                            <Extensions>
                              <ns3:TPX xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                                <ns3:Watts>\(point.power)</ns3:Watts>
                              </ns3:TPX>
                            </Extensions>
                          </Trackpoint>
                """
            }
        } else {
            // Fallback: single trackpoint with averages
            tcx += """
            
                      <Trackpoint>
                        <Time>\(startTime)</Time>
                        <HeartRateBpm><Value>\(session.avgHeartRate)</Value></HeartRateBpm>
                        <Cadence>\(session.avgCadence)</Cadence>
                        <Extensions>
                          <ns3:TPX xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                            <ns3:Watts>\(session.avgPower)</ns3:Watts>
                          </ns3:TPX>
                        </Extensions>
                      </Trackpoint>
            """
        }
        
        tcx += """
        
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        
        return tcx.data(using: .utf8) ?? Data()
    }
}

// MARK: - Response Models

struct StravaTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: Int
    let athlete: StravaAthlete
}

struct StravaRefreshResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: Int
}

struct StravaAthlete: Codable {
    let firstname: String
    let lastname: String
}

// MARK: - Detailed Workout Data

struct WorkoutDataPoint: Codable {
    let power: Int
    let cadence: Int
    let heartRate: Int
}
