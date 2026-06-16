import Foundation

enum AppSection: String, CaseIterable {
    case monitor
    case status
    case tasks

    var sfSymbolName: String {
        switch self {
        case .monitor: return "waveform.path.ecg"
        case .status: return "lock.shield"
        case .tasks: return "clock.arrow.2.circlepath"
        }
    }

    var displayName: String {
        switch self {
        case .monitor: return "Monitor"
        case .status: return "Status"
        case .tasks: return "Tasks"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .monitor: return "System Monitor"
        case .status: return "System Status Controls"
        case .tasks: return "Scheduled Tasks"
        }
    }
}
