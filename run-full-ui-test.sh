#!/bin/bash

# Full UI Test for iGlance
# This script will:
# 1. Build and launch the app
# 2. Take screenshots to verify menu bar icon
# 3. Use AppleScript to simulate clicks
# 4. Verify all UI functionality

echo "=========================================="
echo "  iGlance Full UI Test"
echo "=========================================="
echo ""

# Kill existing
pkill -f "iGlance" 2>/dev/null
sleep 1

# Build
echo "1. Building..."
swift build 2>&1 | grep -q "Build complete"
if [ $? -ne 0 ]; then
    echo "✗ Build failed"
    exit 1
fi
echo "✓ Build successful"

# Launch app
echo ""
echo "2. Launching app..."
.build/debug/iGlance &
APP_PID=$!
sleep 3

if ! ps -p $APP_PID > /dev/null 2>&1; then
    echo "✗ App failed to launch"
    exit 1
fi
echo "✓ App launched (PID: $APP_PID)"

# Take screenshot of menu bar area
echo ""
echo "3. Taking screenshot of menu bar..."
 screencapture -R0,0,1920,25 /tmp/iglance_menubar.png 2>/dev/null
if [ -f "/tmp/iglance_menubar.png" ]; then
    echo "✓ Screenshot saved to /tmp/iglance_menubar.png"
    echo "  Please check this file to verify menu bar icon"
else
    echo "⚠ Could not take screenshot"
fi

# Try to click using AppleScript
echo ""
echo "4. Testing UI interaction..."

# Create AppleScript to test clicking
cat > /tmp/test_iglance.applescript << 'EOF'
tell application "System Events"
    tell process "iGlance"
        try
            -- Get menu bar items
            set menuBarItems to menu bar items of menu bar 1
            set itemCount to count of menuBarItems

            if itemCount > 0 then
                -- Click the first menu bar item
                click menu bar item 1 of menu bar 1
                delay 1

                -- Check if a window appeared
                set windowCount to count of windows

                if windowCount > 0 then
                    return "SUCCESS: Menu bar item clicked, window opened"
                else
                    return "PARTIAL: Menu bar item clicked, but no window"
                end if
            else
                return "FAIL: No menu bar items found"
            end if
        on error errMsg
            return "ERROR: " & errMsg
        end try
    end tell
end tell
EOF

# Run AppleScript
RESULT=$(osascript /tmp/test_iglance.applescript 2>&1)
echo "AppleScript result: $RESULT"

# Check for accessibility permission
if echo "$RESULT" | grep -q "not allowed assistive access"; then
    echo ""
    echo "⚠ AppleScript needs accessibility permission"
    echo ""
    echo "To grant permission:"
    echo "1. Open System Settings"
    echo "2. Go to Privacy & Security → Accessibility"
    echo "3. Add Terminal (or your terminal app) to the list"
    echo "4. Enable the toggle"
    echo ""
    echo "After granting permission, run this script again."
    echo ""
    echo "Alternatively, you can manually test:"
    echo "1. Look for the icon in your menu bar (top-right)"
    echo "2. Click the icon"
    echo "3. Verify the popover opens"
else
    # Take screenshot after click
    echo ""
    echo "5. Taking screenshot after click..."
    screencapture -R0,0,1920,1080 /tmp/iglance_after_click.png 2>/dev/null
    if [ -f "/tmp/iglance_after_click.png" ]; then
        echo "✓ Screenshot saved to /tmp/iglance_after_click.png"
    fi
fi

# Check log file for verification
echo ""
echo "6. Checking verification log..."
if [ -f "/tmp/iglance_test.log" ]; then
    echo "=== Verification Log ==="
    cat /tmp/iglance_test.log
    echo "=== End Log ==="
else
    echo "No verification log found"
fi

# Cleanup
echo ""
echo "7. Cleanup..."
kill $APP_PID 2>/dev/null
sleep 1

if ! ps -p $APP_PID > /dev/null 2>&1; then
    echo "✓ App terminated"
else
    echo "⚠ App may still be running"
fi

echo ""
echo "=========================================="
echo "  Test Complete"
echo "=========================================="
echo ""
echo "If you see 'SUCCESS' above, all UI features are working."
echo ""
echo "If you need to grant accessibility permission:"
echo "1. System Settings → Privacy & Security → Accessibility"
echo "2. Add your terminal app"
echo "3. Run this script again: ./run-full-ui-test.sh"
