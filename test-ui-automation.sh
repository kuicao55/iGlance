#!/bin/bash

# Automated UI test for iGlance using AppleScript

echo "=== iGlance Automated UI Test ==="
echo ""

PASS=0
FAIL=0

check() {
    if [ "$1" = "true" ]; then
        echo "✓ $2"
        ((PASS++))
    else
        echo "✗ $2"
        ((FAIL++))
    fi
}

# Kill existing
pkill -f "iGlance" 2>/dev/null
sleep 1

# Build
echo "1. Building..."
swift build 2>&1 | grep -q "Build complete"
check "$?" "Build successful"

# Launch app
echo ""
echo "2. Launching app..."
.build/debug/iGlance &
APP_PID=$!
sleep 3

ps -p $APP_PID > /dev/null 2>&1
check "$?" "App is running"

echo ""
echo "3. Testing menu bar icon..."

# Use AppleScript to check if menu bar has our icon
ICON_CHECK=$(osascript -e '
tell application "System Events"
    tell process "iGlance"
        try
            set menuBarItems to menu bar items of menu bar 1
            return "found"
        on error
            return "not_found"
        end try
    end tell
end tell
' 2>&1)

if echo "$ICON_CHECK" | grep -q "found"; then
    check "true" "Menu bar icon exists"
else
    check "false" "Menu bar icon exists"
fi

echo ""
echo "4. Testing popover open..."

# Try to click the menu bar item
CLICK_RESULT=$(osascript -e '
tell application "System Events"
    tell process "iGlance"
        try
            click menu bar item 1 of menu bar 1
            delay 1
            return "clicked"
        on error errMsg
            return "error: " & errMsg
        end try
    end tell
end tell
' 2>&1)

if echo "$CLICK_RESULT" | grep -q "clicked"; then
    check "true" "Menu bar icon is clickable"
else
    check "false" "Menu bar icon is clickable (Error: $CLICK_RESULT)"
fi

echo ""
echo "5. Checking popover window..."

# Check if a window appeared
WINDOW_CHECK=$(osascript -e '
tell application "System Events"
    tell process "iGlance"
        try
            set windowCount to count of windows
            if windowCount > 0 then
                return "has_windows"
            else
                return "no_windows"
            end if
        on error
            return "error"
        end try
    end tell
end tell
' 2>&1)

if echo "$WINDOW_CHECK" | grep -q "has_windows"; then
    check "true" "Popover window opened"
else
    check "false" "Popover window opened"
fi

echo ""
echo "6. Testing tab switching..."

# Try to find and click tabs
TAB_TEST=$(osascript -e '
tell application "System Events"
    tell process "iGlance"
        try
            -- Look for buttons in the window
            tell window 1
                set allButtons to every button
                set buttonCount to count of allButtons
                return "buttons: " & buttonCount
            end tell
        on error errMsg
            return "error: " & errMsg
        end try
    end tell
end tell
' 2>&1)

echo "   Tab test result: $TAB_TEST"

echo ""
echo "7. Testing stability..."

# Let it run for 5 seconds
sleep 5

ps -p $APP_PID > /dev/null 2>&1
check "$?" "App stable after 5 seconds"

echo ""
echo "8. Cleanup..."
kill $APP_PID 2>/dev/null
sleep 1

! ps -p $APP_PID > /dev/null 2>&1
check "$?" "App terminated cleanly"

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ $FAIL -eq 0 ]; then
    echo ""
    echo "All automated tests passed!"
    exit 0
else
    echo ""
    echo "Some tests failed. Check the output above."
    exit 1
fi
