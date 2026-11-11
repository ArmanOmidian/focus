import SwiftUI

// MARK: - Task

enum Priority: String, Codable, CaseIterable, Identifiable {
    case high, medium, low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .high: return Color(hex: "#E5484D")
        case .medium: return Color(hex: "#D9822B")
        case .low: return Color(hex: "#7C7F8A")
        }
    }
}

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var priority: Priority = .medium
    /// Due date and time. Nil = no due date.
    var due: Date?
    var createdAt: Date = Date()
    /// Set when checked. Completed tasks are deleted automatically after `keepCompletedDays`.
    var completedAt: Date?

    init(title: String, priority: Priority = .medium) {
        self.title = title
        self.priority = priority
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        due = try c.decodeIfPresent(Date.self, forKey: .due)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

// MARK: - Settings

enum ReminderOffset: Int, Codable, CaseIterable, Identifiable {
    case atTime = 0, min5 = 5, min10 = 10, min15 = 15, min30 = 30, hour1 = 60, day1 = 1440

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .atTime: return "At due time"
        case .min5: return "5 minutes before"
        case .min10: return "10 minutes before"
        case .min15: return "15 minutes before"
        case .min30: return "30 minutes before"
        case .hour1: return "1 hour before"
        case .day1: return "1 day before"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct AppSettings: Codable, Equatable {
    // Pomodoro
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var autoSwitchToBreak = true
    var soundEnabled = true
    var soundVolume: Double = 0.8
    var showTimerInMenuBar = true
    // Reminders
    var notificationsEnabled = true
    var reminder: ReminderOffset = .atTime
    // Tasks
    var keepCompletedDays = 7
    // Look
    var theme: AppTheme = .light

    init() {}

    // Tolerant decoding: adding a new setting never breaks an existing data file.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        autoSwitchToBreak = try c.decodeIfPresent(Bool.self, forKey: .autoSwitchToBreak) ?? d.autoSwitchToBreak
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        soundVolume = try c.decodeIfPresent(Double.self, forKey: .soundVolume) ?? d.soundVolume
        showTimerInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showTimerInMenuBar) ?? d.showTimerInMenuBar
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        reminder = try c.decodeIfPresent(ReminderOffset.self, forKey: .reminder) ?? d.reminder
        keepCompletedDays = try c.decodeIfPresent(Int.self, forKey: .keepCompletedDays) ?? d.keepCompletedDays
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? d.theme
    }
}

// MARK: - Everything saved to disk

struct AppData: Codable, Equatable {
    /// Order in this array = the order you arranged by drag and drop.
    var tasks: [TaskItem] = []
    var settings = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }

    static func sample() -> AppData {
        var d = AppData()
        var a = TaskItem(title: "Plan the week", priority: .high)
        a.due = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())
        let b = TaskItem(title: "Reply to emails", priority: .medium)
        let c = TaskItem(title: "Tidy up the desktop", priority: .low)
        d.tasks = [a, b, c]
        return d
    }
}
