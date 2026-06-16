# iGlance Interactive Test Guide

## Quick Start

Run the app:
```bash
open iGlance.app
```

## Test Procedure

### Step 1: Verify Menu Bar Icon
1. Look at the top-right of your screen (menu bar)
2. You should see a small eye-like icon
3. **Expected**: Icon is visible and monochrome

### Step 2: Test Popover Open/Close
1. Click the menu bar icon
2. **Expected**: A popover window opens below the icon
3. Click anywhere outside the popover
4. **Expected**: Popover closes

### Step 3: Test Monitor Tab
1. Click the menu bar icon to open popover
2. You should see "Monitor" tab selected by default
3. **Expected**: Four cards in 2x2 grid:
   - CPU (top-left)
   - GPU (top-right)
   - Memory (bottom-left)
   - Temperature (bottom-right)

#### Test CPU Card
1. Observe the CPU card
2. **Expected**:
   - Circular gauge showing percentage
   - CPU model name below
3. Click the CPU card
4. **Expected**: Card flips to show:
   - 60-second sparkline chart
   - Top 5 CPU-consuming processes
5. Click again to flip back

#### Test GPU Card
1. Observe the GPU card
2. **Expected**:
   - Gauge showing GPU usage (or "Unavailable" if not supported)
3. Click to flip
4. **Expected**: Shows GPU history and temperature (if available)

#### Test Memory Card
1. Observe the Memory card
2. **Expected**:
   - Gauge showing memory usage percentage
   - Pressure level (Normal/Warning/Critical)
3. Click to flip
4. **Expected**: Shows memory history and top processes

#### Test Temperature Card
1. Observe the Temperature card
2. **Expected**:
   - Three temperature bars (CPU, GPU, SSD)
   - Color coded: green → yellow → red
   - Temperature values displayed

### Step 4: Test Status Tab
1. Click "Status" tab at the top
2. **Expected**: Three sections visible

#### Test System Sleep Toggle
1. Click "Prevent System Sleep" toggle
2. **Expected**: Toggle turns on, Mac won't sleep
3. Click again to turn off
4. **Expected**: Toggle turns off, sleep allowed

#### Test Display Sleep Toggle
1. Click "Prevent Display Sleep" toggle
2. **Expected**: Toggle turns on, display won't sleep
3. Click again to turn off
4. **Expected**: Toggle turns off, display sleep allowed

#### Verify SleepDisabled Indicator
1. Look at "System Sleep Disabled" section
2. **Expected**:
   - Shows "Enabled" or "Disabled"
   - Color indicator (red dot for enabled, green for disabled)

### Step 5: Test Tasks Tab
1. Click "Tasks" tab at the top
2. **Expected**: List of scheduled tasks

#### Verify Task Sources
1. Look for tasks from different sources:
   - LaunchAgents (person icon)
   - LaunchDaemons (computer icon)
   - Cron (clock icon)
   - At (clock with exclamation)
2. Each task should show:
   - Source icon
   - Task name
   - Schedule description
   - Running status (green dot if running)

### Step 6: Test Real-Time Updates
1. Switch back to Monitor tab
2. Open Activity Monitor (Applications → Utilities)
3. Run a CPU-intensive task (e.g., `yes > /dev/null &`)
4. Observe iGlance
5. **Expected**:
   - CPU gauge increases
   - Sparkline shows spike
   - Menu bar icon arc grows
6. Stop the task
7. **Expected**: Values return to normal

### Step 7: Test Menu Bar Icon Updates
1. Close the popover
2. Run CPU-intensive task again
3. Observe menu bar icon
4. **Expected**: Icon arc grows with load
5. Stop task
6. **Expected**: Icon arc shrinks

### Step 8: Test Cleanup
1. Enable both sleep prevention toggles
2. Quit iGlance (Cmd+Q or Activity Monitor)
3. **Expected**:
   - App quits cleanly
   - No leftover processes
   - Sleep prevention released

## Troubleshooting

### Icon Not Visible
- Check if app is running: `ps aux | grep iGlance`
- Try quitting and relaunching

### GPU Shows "Unavailable"
- This is normal on some hardware
- GPU monitoring requires specific drivers

### No Tasks Listed
- This is normal if you have no scheduled tasks
- Tasks come from LaunchAgents, LaunchDaemons, cron, and at

### Temperature Shows "N/A"
- Temperature sensors may need elevated privileges
- Some sensors may not be accessible

## Verification Checklist

After completing all tests, check these boxes:

- [ ] Menu bar icon visible
- [ ] Popover opens/closes correctly
- [ ] Monitor tab shows 4 cards
- [ ] CPU card shows gauge and flips
- [ ] GPU card shows gauge (or unavailable)
- [ ] Memory card shows gauge and flips
- [ ] Temperature card shows 3 bars
- [ ] Status tab toggles work
- [ ] Tasks tab shows scheduled jobs
- [ ] Values update in real-time
- [ ] Menu bar icon reflects load
- [ ] App quits cleanly
- [ ] No leftover processes

## Reporting Issues

If any test fails:
1. Note which test failed
2. Check Console.app for error messages
3. Run `./verify-app.sh` for automated diagnostics
4. Report the issue with details

## Final Verification

All tests passed? Your iGlance is ready for daily use!

```bash
# To install permanently:
cp -R iGlance.app /Applications/

# To add to login items:
# System Settings → General → Login Items → Add iGlance
```
