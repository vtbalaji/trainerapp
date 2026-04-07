# Tacx Trainer Control — iOS App Plan

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Language | Swift | Native performance, best BLE support |
| UI | SwiftUI | Modern, declarative, less boilerplate |
| BLE | CoreBluetooth | Apple's native BLE framework |
| Protocol | FTMS (Fitness Machine Service) | Industry standard, Tacx supports it |
| Data | SwiftData | Persist training plans & workout history |
| Architecture | MVVM | Clean separation, works well with SwiftUI |

## BLE/FTMS Details

- **FTMS Service UUID**: `0x1826`
- **Indoor Bike Data Characteristic** (`0x2AD2`): reads power, cadence, speed
- **Fitness Machine Control Point** (`0x2AD9`): write resistance level, target power, simulation parameters
- **Resistance control modes**:
  - **Target Power (ERG mode)**: set exact wattage, trainer auto-adjusts
  - **Simulation mode**: set gradient/wind/weight, trainer simulates road
  - **Resistance level**: set raw resistance percentage

## App Features (MVP)

1. **Trainer Discovery & Connection** — scan, pair, auto-reconnect
2. **Live Dashboard** — real-time power, cadence, speed, resistance display
3. **Manual Control** — slider/buttons to set resistance or target power
4. **Training Plan Builder** — create interval workouts with target power/duration
5. **Workout Execution** — follow a plan with auto-resistance changes, timer, progress bar
6. **Workout History** — save completed sessions with summary stats

## Project Structure

```
TrainerApp/
├── TrainerApp.swift              # App entry point
├── Models/
│   ├── TrainingPlan.swift        # Plan with intervals
│   ├── WorkoutInterval.swift     # Single interval (power, duration)
│   └── WorkoutSession.swift      # Completed workout record
├── Services/
│   ├── BluetoothManager.swift    # CoreBluetooth scanning & connection
│   └── TrainerService.swift      # FTMS protocol: parse data, send commands
├── ViewModels/
│   ├── DashboardViewModel.swift  # Live data binding
│   ├── PlanBuilderViewModel.swift
│   └── WorkoutViewModel.swift    # Execution engine (timer, auto-resistance)
├── Views/
│   ├── ScanView.swift            # Trainer discovery
│   ├── DashboardView.swift       # Live metrics + manual control
│   ├── PlanBuilderView.swift     # Create/edit plans
│   ├── WorkoutView.swift         # Execute a plan
│   └── HistoryView.swift         # Past sessions
└── Utilities/
    └── FTMSConstants.swift       # BLE UUIDs, command builders
```

## Implementation Phases

### Phase 1 — BLE Connection + Live Data (CURRENT)
- CoreBluetooth scanning for FTMS devices
- Connect, discover services, subscribe to Indoor Bike Data
- Parse power/cadence/speed from BLE notifications
- Display on a live dashboard

### Phase 2 — Resistance Control
- Write to FTMS Control Point to set target power or resistance
- Manual control UI with slider + presets
- ERG mode (constant power) support

### Phase 3 — Training Plans
- Data model for plans (array of intervals with target power + duration)
- Plan builder UI (add/edit/reorder intervals)
- Persist plans with SwiftData

### Phase 4 — Workout Execution
- Timer-driven workout engine
- Auto-set resistance per interval
- Visual progress (current interval, time remaining, target vs actual power)

### Phase 5 — History & Polish
- Save completed workouts
- Summary stats (avg power, duration, TSS)
- Charts for workout review

## Notes

- Modern Tacx trainers (Neo 2T, Flux 2, etc.) support BLE FTMS directly
- iOS requires `NSBluetoothAlwaysUsageDescription` in Info.plist
- macOS also supports CoreBluetooth — can test on MacBook Pro directly
- BLE does NOT work in the iOS Simulator — use real device or Mac
- Older Tacx models may need proprietary Tacx BLE protocol instead of FTMS
