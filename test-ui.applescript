-- iGlance UI Test Script
-- This script tests the basic UI interactions

tell application "System Events"
    -- Launch iGlance
    tell application "iGlance" to activate
    delay 2

    -- Check if iGlance is running
    set isRunning to (exists process "iGlance")

    if isRunning then
        -- Try to find the menu bar item
        -- Note: Menu bar items are difficult to test via AppleScript
        -- This test verifies the app launches and stays running

        set testResults to {}

        -- Test 1: App is running
        set end of testResults to "✓ App is running"

        -- Test 2: Wait and check stability
        delay 5
        set isStillRunning to (exists process "iGlance")
        if isStillRunning then
            set end of testResults to "✓ App is stable (5 second test)"
        else
            set end of testResults to "✗ App crashed during stability test"
        end if

        -- Test 3: Check if app has windows (it shouldn't have a main window)
        tell process "iGlance"
            set windowCount to count of windows
            if windowCount = 0 then
                set end of testResults to "✓ No main window (correct for menu bar app)"
            else
                set end of testResults to "⚠ App has " & windowCount & " windows"
            end if
        end tell

        -- Test 4: Memory usage
        set memUsage to do shell script "ps -o rss= -p $(pgrep -f iGlance.app/Contents/MacOS/iGlance) | tr -d ' '"
        set memMB to (memUsage as number) / 1024
        if memMB < 200 then
            set end of testResults to "✓ Memory usage OK: " & (round memMB) & "MB"
        else
            set end of testResults to "⚠ Memory usage high: " & (round memMB) & "MB"
        end if

        -- Test 5: Check process CPU usage
        set cpuUsage to do shell script "ps -o pcpu= -p $(pgrep -f iGlance.app/Contents/MacOS/iGlance) | tr -d ' '"
        if (cpuUsage as number) < 50 then
            set end of testResults to "✓ CPU usage OK: " & cpuUsage & "%"
        else
            set end of testResults to "⚠ CPU usage high: " & cpuUsage & "%"
        end if

        -- Print results
        set output to "=== iGlance UI Test Results ===" & return
        repeat with result in testResults
            set output to output & result & return
        end repeat

        -- Cleanup
        tell application "iGlance" to quit

        return output
    else
        return "✗ Failed to launch iGlance"
    end if
end tell
