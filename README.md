# iGlance

A lightweight macOS menu bar system utility.

## Features

- **Monitor Tab**: Real-time CPU, GPU, Memory, and Temperature monitoring with animated gauges
- **Status Tab**: System sleep prevention controls and sleep-disabled indicator
- **Tasks Tab**: View scheduled background jobs (LaunchAgents, LaunchDaemons, Cron, At)
- **Dynamic Menu Bar Icon**: Reflects system load at a glance

## Installation

### Option 1: Run directly
```bash
open iGlance.app
```

### Option 2: Install to Applications
```bash
cp -R iGlance.app /Applications/
```

### Option 3: Build from source
```bash
./build-app.sh
```

## Requirements

- macOS 14.0 or later
- Swift 5.9+

## Usage

1. Launch iGlance
2. Look for the icon in your menu bar
3. Click the icon to open the popover
4. Switch between Monitor, Status, and Tasks tabs

### Monitor Tab
- CPU, GPU, Memory, and Temperature cards in a 2x2 grid
- Click any card (except Temperature) to flip and see detailed history
- Sparkline charts show 60-second history

### Status Tab
- Toggle "Prevent System Sleep" to keep your Mac awake
- Toggle "Prevent Display Sleep" to keep your screen on
- View system-level SleepDisabled indicator

### Tasks Tab
- View scheduled tasks from LaunchAgents, LaunchDaemons, Cron, and At
- See task schedules and running status

## Architecture

- Pure SwiftUI + AppKit
- No Dock icon (accessory app)
- NSPopover for main UI
- 2-second refresh intervals
- Automatic cleanup of power assertions on quit

## Project Structure

```
iGlance/
├── Sources/
│   └── iGlance/
│       ├── App/              # App entry and lifecycle
│       ├── Controllers/      # Status item and popover controllers
│       ├── Models/           # Data models
│       ├── Services/         # Data providers and system services
│       ├── Stores/           # State management
│       ├── Support/          # Utility classes
│       ├── Views/            # SwiftUI views
│       └── Resources/        # Assets
├── Package.swift
├── build-app.sh
└── iGlance.app              # Built application
```

## Building

```bash
swift build          # Debug build
swift build -c release  # Release build
./build-app.sh       # Build app bundle
```

## Testing

### Automated Tests
```bash
./verify-all-features.sh   # Complete feature verification (12 tests)
./test-core.sh             # Core functionality tests
```

### Test Results
All 12 automated tests passed:
- ✓ Build verification
- ✓ Launch test
- ✓ System integration
- ✓ Stability test
- ✓ Cleanup test

See `FINAL_TEST_REPORT.md` for detailed results.

## Project Documentation

- `README.md` - This file
- `TEST_GUIDE.md` - Manual testing instructions
- `TEST_REPORT.md` - Test results and status
- `PROJECT_SUMMARY.md` - Technical overview
- `docs/plans/iglance-development-plan.md` - Original development blueprint

## License

Copyright © 2024 kui. All rights reserved.
