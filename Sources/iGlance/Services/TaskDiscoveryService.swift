import Foundation

class TaskDiscoveryService {
    private let processRunner: ProcessRunner

    init(processRunner: ProcessRunner) {
        self.processRunner = processRunner
    }

    func discoverAllTasks() -> [TaskEntry] {
        var tasks: [TaskEntry] = []

        tasks.append(contentsOf: discoverLaunchAgents())
        tasks.append(contentsOf: discoverLaunchDaemons())
        tasks.append(contentsOf: discoverCronJobs())
        tasks.append(contentsOf: discoverAtJobs())

        return tasks
    }

    // MARK: - LaunchAgents

    private func discoverLaunchAgents() -> [TaskEntry] {
        let paths = [
            ("~/Library/LaunchAgents", TaskSource.launchAgent),
            ("/Library/LaunchAgents", TaskSource.launchAgent)
        ]

        var tasks: [TaskEntry] = []

        for (path, source) in paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: expandedPath) else { continue }

            for file in files where file.hasSuffix(".plist") {
                let fullPath = (expandedPath as NSString).appendingPathComponent(file)
                if let entry = parsePlist(at: fullPath, source: source) {
                    tasks.append(entry)
                }
            }
        }

        return tasks
    }

    // MARK: - LaunchDaemons

    private func discoverLaunchDaemons() -> [TaskEntry] {
        let path = "/Library/LaunchDaemons"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }

        var tasks: [TaskEntry] = []
        for file in files where file.hasSuffix(".plist") {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let entry = parsePlist(at: fullPath, source: .launchDaemon) {
                tasks.append(entry)
            }
        }

        return tasks
    }

    // MARK: - Plist Parsing

    private func parsePlist(at path: String, source: TaskSource) -> TaskEntry? {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let label = plist["Label"] as? String ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let startInterval = plist["StartInterval"] as? Int
        let startCalendar = plist["StartCalendarInterval"] as? [String: Any]

        var ruleDescription = ""
        var rawRule = ""

        if let interval = startInterval {
            ruleDescription = "Every \(formatInterval(interval))"
            rawRule = "StartInterval: \(interval)"
        } else if let calendar = startCalendar {
            ruleDescription = formatCalendar(calendar)
            rawRule = "StartCalendarInterval: \(calendar)"
        } else {
            ruleDescription = "Event-triggered"
            rawRule = "No schedule"
        }

        let isRunning = checkIfRunning(label: label)

        return TaskEntry(
            id: path,
            source: source,
            label: label,
            ruleDescription: ruleDescription,
            rawRuleText: rawRule,
            isRunning: isRunning,
            nextTrigger: nil,
            notes: nil
        )
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) seconds"
        } else if seconds < 3600 {
            return "\(seconds / 60) minutes"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours) hours"
        }
    }

    private func formatCalendar(_ calendar: [String: Any]) -> String {
        let hour = calendar["Hour"] as? Int ?? -1
        let minute = calendar["Minute"] as? Int ?? -1
        let weekday = calendar["Weekday"] as? Int ?? -1

        var parts: [String] = []
        if weekday >= 0 {
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            parts.append(days[weekday])
        }
        if hour >= 0 && minute >= 0 {
            parts.append(String(format: "%02d:%02d", hour, minute))
        } else if hour >= 0 {
            parts.append("\(hour):00")
        }

        return parts.isEmpty ? "Calendar scheduled" : parts.joined(separator: " ")
    }

    // MARK: - Cron Jobs

    private func discoverCronJobs() -> [TaskEntry] {
        let result = processRunner.runShell("crontab -l 2>/dev/null")
        guard result.terminationStatus == 0, !result.stdout.isEmpty else { return [] }

        var tasks: [TaskEntry] = []
        let lines = result.stdout.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let components = trimmed.components(separatedBy: .whitespaces)
            guard components.count >= 6 else { continue }

            let rule = components.prefix(5).joined(separator: " ")
            let command = components.dropFirst(5).joined(separator: " ")
            let label = (command as NSString).lastPathComponent

            tasks.append(TaskEntry(
                id: "cron-\(index)",
                source: .cron,
                label: label,
                ruleDescription: describeCronRule(rule),
                rawRuleText: rule,
                isRunning: false,
                nextTrigger: nil,
                notes: nil
            ))
        }

        return tasks
    }

    private func describeCronRule(_ rule: String) -> String {
        let parts = rule.components(separatedBy: .whitespaces)
        guard parts.count >= 5 else { return rule }

        let minute = parts[0]
        let hour = parts[1]
        let day = parts[2]
        let month = parts[3]
        let weekday = parts[4]

        if minute == "*" && hour == "*" && day == "*" && month == "*" && weekday == "*" {
            return "Every minute"
        } else if hour == "*" && day == "*" && month == "*" && weekday == "*" {
            return "Every hour at :\(minute)"
        } else if day == "*" && month == "*" && weekday == "*" {
            return "Daily at \(hour):\(minute)"
        } else if month == "*" && weekday == "*" {
            return "Monthly on day \(day) at \(hour):\(minute)"
        }

        return rule
    }

    // MARK: - At Jobs

    private func discoverAtJobs() -> [TaskEntry] {
        let result = processRunner.runShell("atq 2>/dev/null")
        guard result.terminationStatus == 0, !result.stdout.isEmpty else { return [] }

        var tasks: [TaskEntry] = []
        let lines = result.stdout.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let components = trimmed.components(separatedBy: .whitespaces)
            guard let jobId = components.first else { continue }

            let timeStr = components.dropFirst().joined(separator: " ")

            tasks.append(TaskEntry(
                id: "at-\(jobId)",
                source: .at,
                label: "Job #\(jobId)",
                ruleDescription: timeStr,
                rawRuleText: trimmed,
                isRunning: false,
                nextTrigger: timeStr,
                notes: nil
            ))
        }

        return tasks
    }

    // MARK: - Helpers

    private func checkIfRunning(label: String) -> Bool {
        let result = processRunner.runShell("launchctl list | grep -q '\(label)' && echo 'yes' || echo 'no'")
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "yes"
    }
}
