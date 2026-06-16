import Foundation
import IOKit.pwr_mgt

class PowerAssertionService {
    private var systemSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0
    private var systemSleepAssertionActive = false
    private var displaySleepAssertionActive = false

    private let processRunner = ProcessRunner()

    func preventSystemSleep() -> Bool {
        guard !systemSleepAssertionActive else { return true }

        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "iGlance: Prevent System Sleep" as CFString,
            &systemSleepAssertionID
        )

        if success == kIOReturnSuccess {
            systemSleepAssertionActive = true
            return true
        }
        return false
    }

    func releaseSystemSleepAssertion() {
        guard systemSleepAssertionActive else { return }

        IOPMAssertionRelease(systemSleepAssertionID)
        systemSleepAssertionActive = false
        systemSleepAssertionID = 0
    }

    func preventDisplaySleep() -> Bool {
        guard !displaySleepAssertionActive else { return true }

        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "iGlance: Prevent Display Sleep" as CFString,
            &displaySleepAssertionID
        )

        if success == kIOReturnSuccess {
            displaySleepAssertionActive = true
            return true
        }
        return false
    }

    func releaseDisplaySleepAssertion() {
        guard displaySleepAssertionActive else { return }

        IOPMAssertionRelease(displaySleepAssertionID)
        displaySleepAssertionActive = false
        displaySleepAssertionID = 0
    }

    func isSleepDisabled() -> Bool? {
        let result = processRunner.runShell("pmset -g | grep -i sleepdisabled")
        guard result.terminationStatus == 0 else { return nil }

        let output = result.stdout.lowercased()
        if output.contains("1") {
            return true
        } else if output.contains("0") {
            return false
        }
        return nil
    }
}
