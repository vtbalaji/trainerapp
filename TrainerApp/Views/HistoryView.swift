import SwiftUI

struct HistoryView: View {
    @StateObject private var store = WorkoutHistoryStore.shared
    @StateObject private var strava = StravaService.shared
    
    var body: some View {
        List {
            if store.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Completed workouts will appear here.")
                }
            } else {
                ForEach(store.sessions) { session in
                    WorkoutSessionRow(session: session, strava: strava, store: store)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        store.delete(store.sessions[index])
                    }
                }
            }
        }
    }
}

struct WorkoutSessionRow: View {
    let session: WorkoutSession
    @ObservedObject var strava: StravaService
    @ObservedObject var store: WorkoutHistoryStore
    @State private var isUploading = false
    @State private var showError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.planName)
                    .font(.headline)
                Spacer()
                
                // Strava upload button
                if strava.isConnected {
                    if session.uploadedToStrava {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Button {
                            uploadToStrava()
                        } label: {
                            if isUploading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                }
                
                // Completion status
                if session.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Incomplete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(session.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                StatItem(icon: "clock", value: session.formattedDuration, label: "Time")
                StatItem(icon: "bolt.fill", value: "\(session.avgPower)W", label: "Avg Power")
                StatItem(icon: "arrow.up", value: "\(session.maxPower)W", label: "Max")
                if session.avgHeartRate > 0 {
                    StatItem(icon: "heart.fill", value: "\(session.avgHeartRate)", label: "Avg HR")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .alert("Upload Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(strava.lastError ?? "Unknown error")
        }
    }
    
    private func uploadToStrava() {
        isUploading = true
        Task {
            let success = await strava.uploadWorkout(session)
            isUploading = false
            if success {
                store.markUploaded(session)
            } else {
                showError = true
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .fontWeight(.medium)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
