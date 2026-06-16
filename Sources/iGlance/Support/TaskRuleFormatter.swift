import Foundation

struct TaskRuleFormatter {
    static func formatCronRule(_ rule: String) -> String {
        let parts = rule.components(separatedBy: .whitespaces)
        guard parts.count >= 5 else { return rule }

        let minute = parts[0]
        let hour = parts[1]
        let day = parts[2]
        let month = parts[3]
        let weekday = parts[4]

        var description = ""

        // Weekday
        if weekday != "*" {
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            if let dayNum = Int(weekday), dayNum >= 0, dayNum <= 6 {
                description += days[dayNum] + " "
            }
        }

        // Time
        if hour != "*" && minute != "*" {
            description += String(format: "%@:%@", hour, minute)
        } else if hour == "*" && minute != "*" {
            description += "every hour at:\(minute)"
        } else if hour != "*" && minute == "*" {
            description += "\(hour):00"
        } else {
            description += "every minute"
        }

        // Day of month
        if day != "*" && month != "*" {
            description += " on \(month)/\(day)"
        } else if day != "*" {
            description += " on day \(day)"
        }

        return description.trimmingCharacters(in: .whitespaces)
    }

    static func formatLaunchdInterval(_ seconds: Int) -> String {
        if seconds < 60 {
            return "Every \(seconds) seconds"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "Every \(mins) minute\(mins == 1 ? "" : "s")"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            if mins > 0 {
                return "Every \(hours)h \(mins)m"
            } else {
                return "Every \(hours) hour\(hours == 1 ? "" : "s")"
            }
        }
    }

    static func formatLaunchdCalendar(_ calendar: [String: Any]) -> String {
        let hour = calendar["Hour"] as? Int ?? -1
        let minute = calendar["Minute"] as? Int ?? -1
        let weekday = calendar["Weekday"] as? Int ?? -1
        let day = calendar["Day"] as? Int ?? -1
        let month = calendar["Month"] as? Int ?? -1

        var parts: [String] = []

        // Weekday
        if weekday >= 0 {
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            if weekday <= 6 {
                parts.append(days[weekday])
            }
        }

        // Time
        if hour >= 0 && minute >= 0 {
            parts.append(String(format: "%02d:%02d", hour, minute))
        } else if hour >= 0 {
            parts.append("\(hour):00")
        }

        // Date
        if month >= 0 && day >= 0 {
            parts.append("\(month)/\(day)")
        } else if day >= 0 {
            parts.append("day \(day)")
        }

        return parts.isEmpty ? "Calendar scheduled" : parts.joined(separator: " ")
    }
}
