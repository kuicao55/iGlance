import Foundation

struct PowerAssertionState {
    var preventSystemSleep: Bool = false
    var preventDisplaySleep: Bool = false
    var systemSleepDisabled: Bool? = nil  // nil = unknown
}
