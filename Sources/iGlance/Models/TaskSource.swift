import Foundation

enum TaskSource: String {
    case launchAgent = "LaunchAgent"
    case launchDaemon = "LaunchDaemon"
    case cron = "Cron"
    case at = "At"

    var sfSymbolName: String {
        switch self {
        case .launchAgent: return "person.crop.circle.badge.clock"
        case .launchDaemon: return "desktopcomputer"
        case .cron: return "clock"
        case .at: return "clock.badge.exclamationmark"
        }
    }
}
