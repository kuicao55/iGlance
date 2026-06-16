import Foundation

struct TaskEntry: Identifiable {
    let id: String
    let source: TaskSource
    let label: String
    let ruleDescription: String
    let rawRuleText: String
    let isRunning: Bool
    let nextTrigger: String?
    let notes: String?
}
