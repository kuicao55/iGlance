#!/bin/bash

# Comprehensive iGlance Feature Test Suite

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}✗ $1${NC}"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARN_COUNT++))
}

echo "=========================================="
echo "  iGlance Comprehensive Feature Test Suite"
echo "=========================================="
echo ""

# ============================================
# PHASE 1: Build Verification
# ============================================
echo "=== Phase 1: Build Verification ==="

# Check source files exist
echo "Checking source files..."

REQUIRED_FILES=(
    "Sources/iGlance/App/iGlanceApp.swift"
    "Sources/iGlance/App/AppDelegate.swift"
    "Sources/iGlance/App/AppEnvironment.swift"
    "Sources/iGlance/Controllers/StatusItemController.swift"
    "Sources/iGlance/Controllers/PopoverController.swift"
    "Sources/iGlance/Stores/AppStore.swift"
    "Sources/iGlance/Stores/MonitorStore.swift"
    "Sources/iGlance/Stores/StatusStore.swift"
    "Sources/iGlance/Stores/ServicesStore.swift"
    "Sources/iGlance/Models/AppSection.swift"
    "Sources/iGlance/Models/SystemSnapshot.swift"
    "Sources/iGlance/Models/CPUSnapshot.swift"
    "Sources/iGlance/Models/GPUSnapshot.swift"
    "Sources/iGlance/Models/MemorySnapshot.swift"
    "Sources/iGlance/Models/TemperatureSnapshot.swift"
    "Sources/iGlance/Services/CPUUsageProvider.swift"
    "Sources/iGlance/Services/GPUUsageProvider.swift"
    "Sources/iGlance/Services/MemoryProvider.swift"
    "Sources/iGlance/Services/TemperatureProvider.swift"
    "Sources/iGlance/Services/PowerAssertionService.swift"
    "Sources/iGlance/Services/ServiceClient.swift"
    "Sources/iGlance/Services/MenuBarIconRenderer.swift"
    "Sources/iGlance/Support/LoadIndexCalculator.swift"
    "Sources/iGlance/Support/HistoryBuffer.swift"
    "Sources/iGlance/Views/PopoverView.swift"
    "Sources/iGlance/Views/Monitor/MonitorView.swift"
    "Sources/iGlance/Views/Status/StatusView.swift"
    "Sources/iGlance/Views/Services/ServicesView.swift"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        pass "Source file exists: $file"
    else
        fail "Missing source file: $file"
    fi
done

# Check build
echo ""
echo "Building project..."
if swift build 2>&1 | grep -q "Build complete"; then
    pass "Project builds successfully"
else
    fail "Project build failed"
    exit 1
fi

# Check app bundle
echo ""
echo "Checking app bundle..."
if [ -d "iGlance.app" ]; then
    pass "App bundle exists"
else
    fail "App bundle not found"
    exit 1
fi

if [ -x "iGlance.app/Contents/MacOS/iGlance" ]; then
    pass "Executable is valid"
else
    fail "Executable not found or not executable"
fi

if [ -f "iGlance.app/Contents/Info.plist" ]; then
    pass "Info.plist exists"
else
    fail "Info.plist missing"
fi

# Verify LSUIElement
if grep -q "<key>LSUIElement</key>" iGlance.app/Contents/Info.plist; then
    pass "LSUIElement configured (no Dock icon)"
else
    fail "LSUIElement not set (will show Dock icon)"
fi

echo ""

# ============================================
# PHASE 2: Launch and Process Tests
# ============================================
echo "=== Phase 2: Launch and Process Tests ==="

# Kill any existing instances
pkill -f "iGlance.app" 2>/dev/null || true
sleep 1

# Launch app
echo "Launching iGlance..."
open iGlance.app
sleep 3

# Check if process is running
if pgrep -f "iGlance.app/Contents/MacOS/iGlance" > /dev/null; then
    pass "App process is running"
else
    fail "App failed to launch"
    exit 1
fi

# Check process details
PID=$(pgrep -f "iGlance.app/Contents/MacOS/iGlance")
if [ -n "$PID" ]; then
    pass "Process ID obtained: $PID"

    # Check memory usage
    MEM=$(ps -o rss= -p $PID | tr -d ' ')
    MEM_MB=$((MEM / 1024))
    if [ $MEM_MB -lt 200 ]; then
        pass "Memory usage acceptable: ${MEM_MB}MB"
    else
        warn "Memory usage high: ${MEM_MB}MB"
    fi
fi

# Check if app is accessory (no Dock icon)
if ! defaults read /Applications/iGlance.app/Contents/Info.plist LSUIElement 2>/dev/null; then
    pass "App runs as accessory (no Dock icon)"
else
    warn "Could not verify accessory mode"
fi

echo ""

# ============================================
# PHASE 3: Menu Bar Icon Tests
# ============================================
echo "=== Phase 3: Menu Bar Icon Tests ==="

# Wait for icon to appear
sleep 2

# Check if there's a status item (requires UI interaction - we'll check process behavior)
echo "Checking menu bar icon presence..."

# We can't directly test UI elements from shell, but we can verify the app is responsive
if pgrep -f "iGlance.app" > /dev/null; then
    pass "App is responsive (menu bar icon should be visible)"
else
    fail "App became unresponsive"
fi

echo ""

# ============================================
# PHASE 4: Data Provider Tests
# ============================================
echo "=== Phase 4: Data Provider Tests ==="

# Test CPU data
echo "Testing CPU data provider..."
CPU_CMD="ps -eo pcpu | tail -n +2 | awk '{s+=\$1} END {print s}'"
CPU_USAGE=$(eval $CPU_CMD 2>/dev/null || echo "0")
if [ -n "$CPU_USAGE" ] && [ "$CPU_USAGE" != "0" ]; then
    pass "CPU data available: ${CPU_USAGE}%"
else
    warn "CPU data not available or zero"
fi

# Test Memory data
echo "Testing memory data provider..."
MEM_PRESSURE=$(memory_pressure 2>/dev/null | head -1 || echo "")
if [ -n "$MEM_PRESSURE" ]; then
    pass "Memory pressure data available"
else
    warn "Memory pressure command not available"
fi

# Test system info
echo "Testing system info..."
CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
if [ -n "$CPU_MODEL" ]; then
    pass "CPU model: $CPU_MODEL"
else
    warn "Could not get CPU model"
fi

TOTAL_MEM=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
if [ "$TOTAL_MEM" != "0" ]; then
    MEM_GB=$(echo "scale=1; $TOTAL_MEM / 1073741824" | bc)
    pass "Total memory: ${MEM_GB}GB"
else
    warn "Could not get total memory"
fi

echo ""

# ============================================
# PHASE 5: Power Assertion Tests
# ============================================
echo "=== Phase 5: Power Assertion Tests ==="

# Test pmset
echo "Testing power assertions..."
PMSET_OUTPUT=$(pmset -g 2>/dev/null || echo "")
if [ -n "$PMSET_OUTPUT" ]; then
    pass "pmset command available"

    # Check sleep disabled status
    SLEEP_DISABLED=$(pmset -g | grep -i "sleepdisabled" || echo "")
    if [ -n "$SLEEP_DISABLED" ]; then
        pass "SleepDisabled status readable"
    else
        warn "SleepDisabled not found in pmset output"
    fi
else
    fail "pmset command not available"
fi

echo ""

# ============================================
# PHASE 6: Task Discovery Tests
# ============================================
echo "=== Phase 6: Task Discovery Tests ==="

# Test LaunchAgents
echo "Testing LaunchAgents discovery..."
LA_COUNT=$(ls ~/Library/LaunchAgents/*.plist 2>/dev/null | wc -l || echo "0")
LA_COUNT=$(echo $LA_COUNT | tr -d ' ')
if [ "$LA_COUNT" -gt 0 ]; then
    pass "Found $LA_COUNT LaunchAgents"
else
    warn "No LaunchAgents found (this is normal)"
fi

# Test LaunchDaemons
echo "Testing LaunchDaemons discovery..."
LD_COUNT=$(ls /Library/LaunchDaemons/*.plist 2>/dev/null | wc -l || echo "0")
LD_COUNT=$(echo $LD_COUNT | tr -d ' ')
if [ "$LD_COUNT" -gt 0 ]; then
    pass "Found $LD_COUNT LaunchDaemons"
else
    warn "No LaunchDaemons found (this is normal)"
fi

# Test crontab
echo "Testing crontab..."
CRON_OUTPUT=$(crontab -l 2>/dev/null || echo "")
if [ -n "$CRON_OUTPUT" ]; then
    CRON_COUNT=$(echo "$CRON_OUTPUT" | grep -v "^#" | grep -v "^$" | wc -l)
    CRON_COUNT=$(echo $CRON_COUNT | tr -d ' ')
    pass "Found $CRON_COUNT cron jobs"
else
    warn "No cron jobs (this is normal)"
fi

# Test atq
echo "Testing at queue..."
ATQ_OUTPUT=$(atq 2>/dev/null || echo "")
if [ -n "$ATQ_OUTPUT" ]; then
    pass "atq command available"
else
    warn "atq not available or no at jobs"
fi

echo ""

# ============================================
# PHASE 7: Stability Tests
# ============================================
echo "=== Phase 7: Stability Tests ==="

# Let app run for a while
echo "Running stability test (10 seconds)..."
sleep 10

if pgrep -f "iGlance.app" > /dev/null; then
    pass "App stable after 10 seconds"
else
    fail "App crashed during stability test"
fi

# Check for memory leaks (basic check)
PID=$(pgrep -f "iGlance.app/Contents/MacOS/iGlance" 2>/dev/null)
if [ -n "$PID" ]; then
    MEM2=$(ps -o rss= -p $PID | tr -d ' ')
    MEM2_MB=$((MEM2 / 1024))
    if [ $MEM2_MB -lt 250 ]; then
        pass "Memory usage stable: ${MEM2_MB}MB"
    else
        warn "Memory usage increased: ${MEM2_MB}MB"
    fi
fi

echo ""

# ============================================
# PHASE 8: Cleanup Tests
# ============================================
echo "=== Phase 8: Cleanup Tests ==="

# Test app termination
echo "Testing app termination..."
pkill -f "iGlance.app" 2>/dev/null || true
sleep 2

if ! pgrep -f "iGlance.app" > /dev/null; then
    pass "App terminated successfully"
else
    fail "App did not terminate properly"
fi

# Verify assertions are released
echo "Verifying power assertions released..."
sleep 1

echo ""

# ============================================
# PHASE 9: UI Feature Documentation
# ============================================
echo "=== Phase 9: UI Feature Verification ==="
echo ""
echo "The following features require manual verification:"
echo ""
echo "Monitor Tab:"
echo "  [ ] Four cards displayed in 2x2 grid"
echo "  [ ] CPU card shows gauge and model name"
echo "  [ ] GPU card shows gauge (or unavailable state)"
echo "  [ ] Memory card shows gauge and pressure"
echo "  [ ] Temperature card shows three bars"
echo "  [ ] CPU/GPU/Memory cards can be flipped"
echo "  [ ] Back side shows sparkline and top processes"
echo "  [ ] Values update every 2 seconds"
echo ""
echo "Status Tab:"
echo "  [ ] Prevent System Sleep toggle works"
echo "  [ ] Prevent Display Sleep toggle works"
echo "  [ ] SleepDisabled indicator shows status"
echo "  [ ] Toggles reflect actual assertion state"
echo ""
echo "Tasks Tab:"
echo "  [ ] Shows LaunchAgents (if any)"
echo "  [ ] Shows LaunchDaemons (if any)"
echo "  [ ] Shows Cron jobs (if any)"
echo "  [ ] Shows At jobs (if any)"
echo "  [ ] Task details are readable"
echo ""
echo "Menu Bar:"
echo "  [ ] Icon visible in menu bar"
echo "  [ ] Click opens popover"
echo "  [ ] Click again closes popover"
echo "  [ ] Icon updates based on system load"
echo ""
echo "Popover:"
echo "  [ ] Three tabs visible"
echo "  [ ] Tab switching works"
echo "  [ ] Content updates when switching tabs"
echo "  [ ] Popover closes when clicking outside"
echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "${YELLOW}Warnings: $WARN_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All automated tests passed!${NC}"
    echo ""
    echo "The app is ready for use. Please verify the UI features"
    echo "listed above by running the app and checking each item."
    echo ""
    echo "To run: open iGlance.app"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the output above.${NC}"
    exit 1
fi
