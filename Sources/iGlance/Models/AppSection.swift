import Foundation

enum AppSection: String, CaseIterable {
    case monitor
    case status
    case services

    var sfSymbolName: String {
        switch self {
        case .monitor: return "waveform.path.ecg"
        case .status: return "lock.shield"
        case .services: return "server.rack"
        }
    }

    var displayName: String {
        switch self {
        case .monitor: return "Monitor"
        case .status: return "Status"
        case .services: return "Services"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .monitor: return "System Monitor"
        case .status: return "System Status Controls"
        case .services: return "Headless Services"
        }
    }
}
