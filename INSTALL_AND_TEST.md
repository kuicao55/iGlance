# iGlance Installation and Testing Guide

## Current Status: ✅ READY FOR USE

The app has been tested and verified to:
1. Build successfully
2. Launch without errors
3. Display menu bar icon
4. Respond to clicks

## Installation

### Step 1: Build the app
```bash
cd /Users/kui/Developer/Tools/iGlance
./build-app.sh
```

### Step 2: Run the app
```bash
open iGlance.app
```

### Step 3: Verify menu bar icon
1. Look at the top-right of your screen (menu bar)
2. You should see a circle icon (◎)
3. Click the icon to open the popover

### Step 4: Install permanently
```bash
cp -R iGlance.app /Applications/
```

### Step 5: Add to login items (optional)
1. Open System Settings
2. Go to General → Login Items
3. Click "+" under "Open at Login"
4. Select iGlance.app

## Testing

### Automated UI Test
```bash
./run-full-ui-test.sh
```

This will:
1. Build and launch the app
2. Take screenshots of the menu bar
3. Test clicking the icon
4. Save screenshots to /tmp/

### Manual Testing

#### Menu Bar Icon
- [ ] Icon visible in top-right of screen
- [ ] Icon is monochrome (adapts to light/dark mode)
- [ ] Clicking icon opens popover/alert

#### Monitor Tab (when fully implemented)
- [ ] CPU usage displays correctly
- [ ] GPU usage displays (or shows N/A)
- [ ] Memory usage displays correctly
- [ ] Temperature bars display
- [ ] Cards can be flipped to show history

#### Status Tab (when fully implemented)
- [ ] "Prevent System Sleep" toggle works
- [ ] "Prevent Display Sleep" toggle works
- [ ] SleepDisabled indicator shows status

#### Tasks Tab (when fully implemented)
- [ ] Shows LaunchAgents
- [ ] Shows LaunchDaemons
- [ ] Shows Cron jobs
- [ ] Shows At jobs

## Troubleshooting

### Icon not visible
1. Check if app is running: `ps aux | grep iGlance`
2. Try quitting and relaunching
3. Check if menu bar is too crowded

### App won't launch
1. Check Console.app for errors
2. Try building again: `swift build`
3. Check macOS version (requires 14.0+)

### Click doesn't work
1. Grant accessibility permission:
   - System Settings → Privacy & Security → Accessibility
   - Add Terminal (or your terminal app)

## File Structure

```
iGlance/
├── iGlance.app                    # Built application
├── Sources/iGlance/               # Source code
│   └── App/
│       └── iGlanceApp.swift       # Main app with status bar
├── Package.swift                  # Build configuration
├── build-app.sh                   # Build script
├── run-full-ui-test.sh            # UI test script
└── INSTALL_AND_TEST.md            # This file
```

## Support

For issues:
1. Check Console.app for error messages
2. Run `./run-full-ui-test.sh` for diagnostics
3. Review this document for troubleshooting

## Next Steps

After verifying the menu bar icon works:
1. The app will be enhanced with full Popover UI
2. All monitoring features will be integrated
3. Sleep controls and task viewer will be added

**Status: Ready for basic use**
