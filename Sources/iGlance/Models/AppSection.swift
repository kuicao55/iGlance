import Foundation

enum AppSection: String, CaseIterable {
    case monitor
    case status
    case services
    case settings

    var sfSymbolName: String {
        switch self {
        case .monitor: return "waveform.path.ecg"
        case .status: return "lock.shield"
        case .services: return "server.rack"
        case .settings: return "gearshape"
        }
    }

    var displayName: String {
        switch self {
        case .monitor: return "Monitor"
        case .status: return "Status"
        case .services: return "Services"
        case .settings: return "Settings"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .monitor: return "System Monitor"
        case .status: return "System Status Controls"
        case .services: return "Headless Services"
        case .settings: return "Settings and Software Update"
        }
    }
}
