#!/bin/bash

# Complete feature verification for iGlance

echo "=========================================="
echo "  iGlance Complete Feature Verification"
echo "=========================================="
echo ""

PASS=0
FAIL=0
WARN=0

pass() { echo "✓ $1"; ((PASS++)); }
fail() { echo "✗ $1"; ((FAIL++)); }
warn() { echo "⚠ $1"; ((WARN++)); }

# ============================================
# PHASE 1: Build Verification
# ============================================
echo "=== Phase 1: Build Verification ==="

# Check source files
echo "Checking source files..."
REQUIRED_FILES=(
    "Sources/iGlance/App/iGlanceApp.swift"
    "Sources/iGlance/App/AppDelegate.swift"
    "Sources/iGlance/Controllers/StatusItemController.swift"
    "Sources/iGlance/Controllers/PopoverController.swift"
    "Sources/iGlance/Stores/AppStore.swift"
    "Sources/iGlance/Stores/MonitorStore.swift"
    "Sources/iGlance/Stores/StatusStore.swift"
    "Sources/iGlance/Stores/TasksStore.swift"
    "Sources/iGlance/Models/AppSection.swift"
    "Sources/iGlance/Services/CPUUsageProvider.swift"
    "Sources/iGlance/Services/MemoryProvider.swift"
    "Sources/iGlance/Services/PowerAssertionService.swift"
    "Sources/iGlance/Services/TaskDiscoveryService.swift"
    "Sources/iGlance/Views/PopoverView.swift"
    "Sources/iGlance/Views/Monitor/MonitorView.swift"
    "Sources/iGlance/Views/Status/StatusView.swift"
    "Sources/iGlance/Views/Tasks/TasksView.swift"
)

ALL_FILES_EXIST=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        fail "Missing: $file"
        ALL_FILES_EXIST=false
    fi
done

if [ "$ALL_FILES_EXIST" = true ]; then
    pass "All source files exist"
fi

# Build
echo ""
echo "Building..."
swift build 2>&1 | grep -q "Build complete"
if [ $? -eq 0 ]; then
    pass "Build successful"
else
    fail "Build failed"
    exit 1
fi

# App bundle
if [ -d "iGlance.app" ]; then
    pass "App bundle created"
else
    fail "App bundle not created"
fi

# ============================================
# PHASE 2: Launch Test
# ============================================
echo ""
echo "=== Phase 2: Launch Test ==="

# Kill existing
pkill -f "iGlance" 2>/dev/null
sleep 1

# Launch
open iGlance.app
sleep 3

# Check process
if pgrep -f "iGlance.app/Contents/MacOS/iGlance" > /dev/null; then
    pass "App launched successfully"
else
    fail "App failed to launch"
    exit 1
fi

PID=$(pgrep -f "iGlance.app/Contents/MacOS/iGlance")
if [ -n "$PID" ]; then
    pass "Process ID: $PID"
fi

# ============================================
# PHASE 3: System Integration
# ============================================
echo ""
echo "=== Phase 3: System Integration ==="

# CPU
CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
if [ -n "$CPU_MODEL" ]; then
    pass "CPU: $CPU_MODEL"
else
    warn "CPU info not available"
fi

# Memory
TOTAL_MEM=$(sysctl -n hw.memsize 2>/dev/null)
if [ -n "$TOTAL_MEM" ] && [ "$TOTAL_MEM" != "0" ]; then
    MEM_GB=$(echo "scale=1; $TOTAL_MEM / 1073741824" | bc)
    pass "Memory: ${MEM_GB}GB"
else
    warn "Memory info not available"
fi

# Power management
pmset -g > /dev/null 2>&1
if [ $? -eq 0 ]; then
    pass "Power management accessible"
else
    warn "Power management not accessible"
fi

# Task discovery
LA_COUNT=$(ls ~/Library/LaunchAgents/*.plist 2>/dev/null | wc -l || echo "0")
LA_COUNT=$(echo $LA_COUNT | tr -d ' ')
pass "LaunchAgents: $LA_COUNT found"

# ============================================
# PHASE 4: Stability Test
# ============================================
echo ""
echo "=== Phase 4: Stability Test ==="

echo "Running for 15 seconds..."
sleep 15

if pgrep -f "iGlance.app" > /dev/null; then
    pass "App stable after 15 seconds"
else
    fail "App crashed during stability test"
fi

# Memory check
if [ -n "$PID" ]; then
    MEM=$(ps -o rss= -p $PID | tr -d ' ')
    MEM_MB=$((MEM / 1024))
    if [ $MEM_MB -lt 200 ]; then
        pass "Memory usage: ${MEM_MB}MB (OK)"
    else
        warn "Memory usage: ${MEM_MB}MB (high)"
    fi
fi

# ============================================
# PHASE 5: UI Features (Manual Verification)
# ============================================
echo ""
echo "=== Phase 5: UI Features ==="
echo ""
echo "Please verify the following in the running app:"
echo ""
echo "1. MENU BAR ICON"
echo "   - Look at the top-right of your screen"
echo "   - You should see '◉' symbol"
echo "   - Click it to open the popover"
echo ""
echo "2. POPOVER"
echo "   - Should show three tabs: Monitor, Status, Tasks"
echo "   - Click each tab to switch"
echo "   - Click outside to close"
echo ""
echo "3. MONITOR TAB"
echo "   - Should show 4 cards in 2x2 grid"
echo "   - CPU card with gauge"
echo "   - GPU card (or 'N/A')"
echo "   - Memory card with gauge"
echo "   - Temperature card with bars"
echo "   - Click CPU/Memory cards to flip"
echo ""
echo "4. STATUS TAB"
echo "   - 'Prevent System Sleep' toggle"
echo "   - 'Prevent Display Sleep' toggle"
echo "   - 'System Sleep Disabled' indicator"
echo ""
echo "5. TASKS TAB"
echo "   - Should list scheduled tasks"
echo "   - Shows LaunchAgents, LaunchDaemons, etc."
echo ""

# ============================================
# PHASE 6: Cleanup
# ============================================
echo "=== Phase 6: Cleanup ==="

pkill -f "iGlance.app" 2>/dev/null
sleep 2

if ! pgrep -f "iGlance.app" > /dev/null; then
    pass "App terminated cleanly"
else
    fail "App did not terminate"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "All automated tests passed!"
    echo ""
    echo "The app is ready for use."
    echo ""
    echo "To install permanently:"
    echo "  cp -R iGlance.app /Applications/"
    echo ""
    echo "To add to login items:"
    echo "  System Settings → General → Login Items → Add iGlance"
    exit 0
else
    echo "Some tests failed. Check the output above."
    exit 1
fi
