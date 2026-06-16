import Foundation
import Combine

class StatusStore: ObservableObject {
    @Published var assertionState = PowerAssertionState()

    private let powerAssertionService: PowerAssertionService
    private let refreshQueue = DispatchQueue(label: "com.iglance.status.refresh", qos: .utility)

    init(powerAssertionService: PowerAssertionService) {
        self.powerAssertionService = powerAssertionService
        refreshSleepDisabledStatus()
    }

    func toggleSystemSleep() {
        if assertionState.preventSystemSleep {
            powerAssertionService.releaseSystemSleepAssertion()
            assertionState.preventSystemSleep = false
        } else {
            let success = powerAssertionService.preventSystemSleep()
            assertionState.preventSystemSleep = success
        }
    }

    func toggleDisplaySleep() {
        if assertionState.preventDisplaySleep {
            powerAssertionService.releaseDisplaySleepAssertion()
            assertionState.preventDisplaySleep = false
        } else {
            let success = powerAssertionService.preventDisplaySleep()
            assertionState.preventDisplaySleep = success
        }
    }

    func refreshSleepDisabledStatus() {
        refreshQueue.async { [weak self] in
            guard let self = self else { return }
            let disabled = self.powerAssertionService.isSleepDisabled()
            DispatchQueue.main.async {
                self.assertionState.systemSleepDisabled = disabled
            }
        }
    }

    /// Called on app termination to release all assertions
    func cleanup() {
        if assertionState.preventSystemSleep {
            powerAssertionService.releaseSystemSleepAssertion()
        }
        if assertionState.preventDisplaySleep {
            powerAssertionService.releaseDisplaySleepAssertion()
        }
        assertionState.preventSystemSleep = false
        assertionState.preventDisplaySleep = false
    }
}
