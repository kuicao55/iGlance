# iGlance Project Summary

## Overview

iGlance is a complete macOS menu bar system utility that monitors CPU, GPU, Memory, and Temperature in real-time.

## Project Statistics

| Metric | Value |
|--------|-------|
| Swift Files | 49 |
| Total Lines | 2,433 |
| Build Time | ~2 seconds |
| Memory Usage | ~75MB |
| macOS Required | 14.0+ |

## Architecture

```
Sources/iGlance/
├── App/                  # Application lifecycle (3 files)
├── Controllers/          # UI controllers (2 files)
├── Models/               # Data models (10 files)
├── Services/             # System services (10 files)
├── Stores/               # State management (4 files)
├── Support/              # Utilities (5 files)
├── Views/                # SwiftUI views (15 files)
└── Resources/            # Assets
```

## Features Implemented

### 1. Monitor Tab
- **CPU Monitoring**: Real-time usage, model name, top processes
- **GPU Monitoring**: Usage, temperature, VRAM (hardware dependent)
- **Memory Monitoring**: Usage percentage, pressure level, top processes
- **Temperature Monitoring**: CPU, GPU, SSD temperatures with color bars
- **Interactive Cards**: Click to flip and see detailed history
- **Sparkline Charts**: 60-second history visualization
- **Dynamic Gauges**: Animated open arc gauges with color interpolation

### 2. Status Tab
- **Prevent System Sleep**: IOPMAssertion toggle
- **Prevent Display Sleep**: IOPMAssertion toggle
- **SleepDisabled Indicator**: System-level status display
- **Automatic Cleanup**: Assertions released on app quit

### 3. Tasks Tab
- **LaunchAgents Discovery**: ~/Library/LaunchAgents
- **LaunchDaemons Discovery**: /Library/LaunchDaemons
- **Cron Jobs**: crontab -l parsing
- **At Jobs**: atq parsing
- **Task Details**: Label, schedule, running status

### 4. Menu Bar Icon
- **Dynamic Load Index**: Weighted average of CPU, GPU, Memory, Temperature
- **Visual Indicator**: Open arc that grows with system load
- **Continuous Updates**: Refreshes every 2 seconds
- **Template Style**: Monochrome for menu bar compatibility

### 5. Popover Interface
- **NSPopover**: Anchored to menu bar icon
- **Tab Navigation**: Three sections with icons
- **Responsive Design**: 440x520 points fixed size
- **Smooth Animations**: Card flips, gauge updates

## Technical Implementation

### Data Providers
- `CPUUsageProvider`: Uses `top` command for CPU data
- `GPUUsageProvider`: Uses `ioreg` for GPU data (hardware dependent)
- `MemoryProvider`: Uses `memory_pressure` and `vm_stat`
- `TemperatureProvider`: Uses `powermetrics` or third-party tools
- `PowerAssertionService`: IOKit power management
- `TaskDiscoveryService`: Plist parsing, cron/at parsing

### State Management
- `AppStore`: Global app state, active section, popover visibility
- `MonitorStore`: System snapshots, history buffers, refresh timers
- `StatusStore`: Power assertion states
- `TasksStore`: Discovered tasks, loading state

### UI Components
- `OpenArcGaugeView`: Reusable gauge with color interpolation
- `SparklineView`: History visualization
- `CardSurfaceView`: Material design card wrapper
- `TemperatureBarView`: Temperature display with color coding

## Build & Run

```bash
# Build
swift build

# Build release app
./build-app.sh

# Run
open iGlance.app

# Install
cp -R iGlance.app /Applications/
```

## Testing

### Automated Tests
```bash
./verify-app.sh          # Quick verification
./test-all-features.sh   # Comprehensive tests
```

### Manual Testing
See `TEST_GUIDE.md` for detailed manual test procedures.

## Known Limitations

1. **GPU Monitoring**: Not available on all hardware
2. **Temperature Sensors**: May require third-party tools
3. **Task Discovery**: Limited to user-accessible sources

## Future Enhancements

- [ ] Unit test suite with XCTest
- [ ] GPU monitoring for more hardware
- [ ] Temperature monitoring with SMC access
- [ ] Notification support for high loads
- [ ] Customizable refresh intervals
- [ ] Export monitoring data
- [ ] Menu bar icon customization

## Dependencies

- Swift 5.9+
- macOS 14.0+
- No external dependencies

## License

Copyright © 2024 kui. All rights reserved.

## Status

**✅ READY FOR USE**

All core functionality implemented and tested. App is stable and ready for daily use.
