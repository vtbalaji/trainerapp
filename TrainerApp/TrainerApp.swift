import SwiftUI

enum AppTab: String, CaseIterable {
    case workouts = "Workouts"
    case dashboard = "Dashboard"
    case control = "Control"
    case history = "History"
    case scale = "Scale"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .workouts: "figure.indoor.cycle"
        case .dashboard: "gauge.with.dots.needle.bottom.50percent"
        case .control: "slider.horizontal.3"
        case .history: "clock.arrow.circlepath"
        case .scale: "scalemass.fill"
        case .settings: "gearshape"
        }
    }
}

@main
struct TrainerApp: App {
    @StateObject private var bluetooth = BluetoothManager()
    @StateObject private var trainerStore = SavedTrainerStore()
    @State private var selectedTab: AppTab = .workouts
    @State private var showMenu = false

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .leading) {
                // Main content
                VStack(spacing: 0) {
                    // Top bar with hamburger menu
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        
                        Text(selectedTab.rawValue)
                            .font(.headline)
                        
                        Spacer()
                        

                    }
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial)
                    
                    // Content
                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView()
                        case .control:
                            ControlView()
                        case .workouts:
                            WorkoutsView()
                        case .history:
                            HistoryView()
                        case .scale:
                            ScaleView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // Dimmed overlay
                if showMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showMenu = false
                            }
                        }
                }
                
                // Side menu
                if showMenu {
                    SideMenuView(selectedTab: $selectedTab, showMenu: $showMenu)
                        .transition(.move(edge: .leading))
                }
            }
            .environmentObject(bluetooth)
            .environmentObject(trainerStore)
            .onChange(of: bluetooth.trainerState) { _, newState in
                if newState == .ready, let id = bluetooth.trainerPeripheralID {
                    let protocolStr: String
                    switch bluetooth.detectedProtocol {
                    case .ftms: protocolStr = "ftms"
                    case .tacxFEC: protocolStr = "tacxFEC"
                    case .unknown: protocolStr = "unknown"
                    }
                    let device = SavedDevice(
                        id: id,
                        name: bluetooth.trainerPeripheralName ?? "Unknown",
                        deviceType: .trainer,
                        protocol_: protocolStr,
                        lastConnected: Date()
                    )
                    trainerStore.save(device)
                }
            }
            .onChange(of: bluetooth.hrState) { _, newState in
                if newState == .ready, let id = bluetooth.hrPeripheralID {
                    let device = SavedDevice(
                        id: id,
                        name: bluetooth.hrDeviceName,
                        deviceType: .heartRate,
                        protocol_: "heartRate",
                        lastConnected: Date()
                    )
                    trainerStore.save(device)
                }
            }
        }
    }
}

struct SideMenuView: View {
    @Binding var selectedTab: AppTab
    @Binding var showMenu: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TrainerApp")
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 30)
            
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMenu = false
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                            .frame(width: 24)
                        Text(tab.rawValue)
                            .font(.body)
                        Spacer()
                    }
                    .foregroundStyle(selectedTab == tab ? .orange : .primary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(selectedTab == tab ? Color.orange.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .frame(width: 250)
        .background(.regularMaterial)
        .ignoresSafeArea(edges: .vertical)
    }
}


