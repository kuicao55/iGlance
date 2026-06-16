import Foundation

struct ProcessMetric: Identifiable {
    let id = UUID()
    let name: String
    let pid: Int32?
    let value: Double  // percentage
    let ranking: Int
}
