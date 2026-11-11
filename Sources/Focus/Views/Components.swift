import SwiftUI
import AppKit

// MARK: - Checkbox

struct CheckBox: View {
    let checked: Bool
    let action: () -> Void
    @Environment(\.palette) private var p
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(checked ? p.text : Color.clear)
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .strokeBorder(checked ? p.text : (hover ? p.muted : p.faint), lineWidth: 1.5)
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(p.background)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Icon button

struct IconButton: View {
    let systemName: String
    var help: String = ""
    var destructive = false
    let action: () -> Void
    @Environment(\.palette) private var p
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hover ? (destructive ? p.danger : p.text) : p.muted)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(hover ? p.hover : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

// MARK: - Priority tag

struct PriorityPill: View {
    let task: TaskItem
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var open = false

    var body: some View {
        Button { if !ui.dragLock { open.toggle() } } label: {
            Text(task.priority.label)
                .font(.jakarta(11, .medium))
                .foregroundStyle(task.priority.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(task.priority.color.opacity(0.11)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Change priority")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Priority.allCases) { pr in
                    MenuRow(selected: pr == task.priority) {
                        store.update(task.id) { $0.priority = pr }
                        open = false
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(pr.color).frame(width: 7, height: 7)
                            Text(pr.label).font(.jakarta(13))
                        }
                    }
                }
            }
            .padding(6)
            .frame(width: 150)
        }
    }
}

struct MenuRow<Label: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var label: () -> Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack {
                label()
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.07) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Due date + time

struct DueButton: View {
    let task: TaskItem
    let rowHover: Bool
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var open = false

    var body: some View {
        Button { if !ui.dragLock { open.toggle() } } label: {
            Group {
                if let due = task.due {
                    HStack(spacing: 4) {
                        Image(systemName: "bell")
                            .font(.system(size: 9, weight: .medium))
                        Text(DueFormat.label(due))
                            .font(.jakarta(11))
                    }
                    .foregroundStyle(due < Date() && task.completedAt == nil ? p.danger : p.muted)
                } else {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(p.muted)
                        .opacity(rowHover || open ? 1 : 0)
                }
            }
            .frame(minHeight: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(task.due == nil ? String("Add a due date") : String("Change due date"))
        .popover(isPresented: $open, arrowEdge: .bottom) {
            DuePopover(task: task) { open = false }
                .environment(\.palette, p)
        }
    }
}

/// Minimal date + time picker: quick chips, a small calendar, and a time ruler you drag.
struct DuePopover: View {
    let task: TaskItem
    let close: () -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.palette) private var p

    @State private var date: Date = DueFormat.suggested()
    @State private var month: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Chip("Today", selected: Calendar.current.isDateInToday(date)) { setDay(offset: 0) }
                Chip("Tomorrow", selected: Calendar.current.isDateInTomorrow(date)) { setDay(offset: 1) }
                Chip("Next week", selected: false) { setDay(offset: 7) }
            }

            MonthGrid(selected: date, month: $month) { day in
                date = DueFormat.combine(day: day, time: date)
            }

            Rectangle().fill(p.border).frame(height: 1)

            TimePicker(date: $date)

            HStack {
                if task.due != nil {
                    TextButton("remove", muted: true) {
                        store.update(task.id) { $0.due = nil }
                        close()
                    }
                }
                Spacer()
                Button {
                    store.update(task.id) { $0.due = date }
                    close()
                } label: {
                    Text("Set")
                        .font(.jakarta(12, .semibold))
                        .foregroundStyle(p.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(p.text))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 272)
        .background(p.background)
        .foregroundStyle(p.text)
        .onAppear {
            date = task.due ?? DueFormat.suggested()
            month = date
        }
    }

    private func setDay(offset: Int) {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        date = DueFormat.combine(day: day, time: date)
        month = date
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var p
    @State private var hover = false

    init(_ title: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.jakarta(11.5, .medium))
                .foregroundStyle(selected ? p.background : p.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(selected ? p.text : (hover ? p.hover : p.field)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// A small, quiet month calendar.
struct MonthGrid: View {
    let selected: Date
    @Binding var month: Date
    let onPick: (Date) -> Void
    @Environment(\.palette) private var p

    private var cal: Calendar { Calendar.current }

    private var days: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        var result: [Date?] = Array(repeating: nil, count: lead)
        for d in 0..<count { result.append(cal.date(byAdding: .day, value: d, to: first)) }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.jakarta(13, .semibold))
                Spacer()
                IconButton(systemName: "chevron.left", help: "Previous month") { shift(-1) }
                IconButton(systemName: "chevron.right", help: "Next month") { shift(1) }
            }

            LazyVGrid(columns: Self.columns, spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    WeekdayLabel(text: weekdaySymbols[i])
                }
                ForEach(0..<days.count, id: \.self) { i in
                    cell(days[i])
                }
            }
        }
    }

    private static let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    @ViewBuilder
    private func cell(_ day: Date?) -> some View {
        if let day {
            DayCell(day: day,
                    selected: cal.isDate(day, inSameDayAs: selected),
                    today: cal.isDateInToday(day),
                    past: isPast(day),
                    action: { onPick(day) })
        } else {
            Color.clear.frame(height: 30)
        }
    }

    private func isPast(_ day: Date) -> Bool {
        day < cal.startOfDay(for: Date())
    }

    private func shift(_ months: Int) {
        if let m = cal.date(byAdding: .month, value: months, to: month) { month = m }
    }
}

private struct WeekdayLabel: View {
    let text: String
    @Environment(\.palette) private var p

    var body: some View {
        Text(text)
            .font(.jakarta(10.5, .medium))
            .foregroundStyle(p.faint)
            .frame(height: 20)
    }
}

private struct DayCell: View {
    let day: Date
    let selected: Bool
    let today: Bool
    let past: Bool
    let action: () -> Void
    @Environment(\.palette) private var p
    @State private var hover = false

    private var number: String { String(Calendar.current.component(.day, from: day)) }
    private var weight: Font.Weight { (today || selected) ? .semibold : .regular }

    private var textColor: Color {
        if selected { return p.background }
        return past ? p.faint : p.text
    }

    private var fillColor: Color {
        if selected { return p.text }
        return hover ? p.hover : Color.clear
    }

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.jakarta(12, weight))
                .foregroundStyle(textColor)
                .frame(width: 30, height: 30)
                .background(Circle().fill(fillColor))
                .overlay(alignment: .bottom) { todayDot }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    @ViewBuilder
    private var todayDot: some View {
        if today && !selected {
            Circle().fill(p.text).frame(width: 3, height: 3).offset(y: -4)
        }
    }
}

/// Time picker in the same style as the timer: drag the ruler across the day (15-minute steps),
/// fine-tune with − / +, or tap a common time.
struct TimePicker: View {
    @Binding var date: Date
    @Environment(\.palette) private var p

    private var cal: Calendar { Calendar.current }

    private var minutesOfDay: Int {
        cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    private static let presets: [Int] = [540, 720, 900, 1080, 1260]   // 9 AM, 12 PM, 3 PM, 6 PM, 9 PM
    private static let rulerLabels: [String] = ["12 AM", "6 AM", "12 PM", "6 PM"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ruler
            presetRow
        }
    }

    private var timeText: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Time")
                .font(.jakarta(12))
                .foregroundStyle(p.muted)
            Spacer()
            IconButton(systemName: "minus", help: "5 minutes earlier") { nudge(-5) }
            Text(timeText)
                .font(.jakarta(24, .light))
                .monospacedDigit()
                .frame(minWidth: 96)
            IconButton(systemName: "plus", help: "5 minutes later") { nudge(5) }
        }
    }

    private var ruler: some View {
        VStack(spacing: 4) {
            TimeRuler(minutes: minutesOfDay, onChange: set)
            HStack(spacing: 0) {
                ForEach(Self.rulerLabels, id: \.self) { t in
                    RulerLabel(text: t)
                }
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(Self.presets, id: \.self) { m in
                PresetChip(minutes: m, current: minutesOfDay, title: label(m), onPick: set)
            }
        }
    }

    private func label(_ m: Int) -> String {
        let d = cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        return d.formatted(.dateTime.hour())
    }

    private func set(_ minutes: Int) {
        let m = max(0, min(24 * 60 - 1, minutes))
        date = cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: date) ?? date
    }

    private func nudge(_ delta: Int) {
        let rounded = (minutesOfDay / 5) * 5
        set(rounded + delta)
    }
}

private struct RulerLabel: View {
    let text: String
    @Environment(\.palette) private var p

    var body: some View {
        Text(text)
            .font(.jakarta(9.5))
            .foregroundStyle(p.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PresetChip: View {
    let minutes: Int
    let current: Int
    let title: String
    let onPick: (Int) -> Void

    var body: some View {
        Chip(title, selected: minutes == current) { onPick(minutes) }
    }
}

struct TimeRuler: View {
    let minutes: Int
    let onChange: (Int) -> Void
    @Environment(\.palette) private var p

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let palette = p
            let fraction = CGFloat(minutes) / CGFloat(24 * 60)

            Canvas { ctx, size in
                let ticks = 48   // every 30 minutes
                for i in 0...ticks {
                    let x = CGFloat(i) / CGFloat(ticks) * (size.width - 1) + 0.5
                    let major = i % 12 == 0   // every 6 hours
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: major ? 2 : 6))
                    path.addLine(to: CGPoint(x: x, y: size.height - (major ? 2 : 6)))
                    ctx.stroke(path, with: .color(palette.tick), lineWidth: 1)
                }
                let ix = fraction * (size.width - 2) + 1
                var indicator = Path()
                indicator.move(to: CGPoint(x: ix, y: 0))
                indicator.addLine(to: CGPoint(x: ix, y: size.height))
                ctx.stroke(indicator, with: .color(palette.text), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard width > 0 else { return }
                        let raw = g.location.x / width * CGFloat(24 * 60)
                        let snapped = Int((raw / 15).rounded()) * 15
                        let value = max(0, min(24 * 60 - 15, snapped))
                        if value != minutes {
                            onChange(value)
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        }
                    }
            )
        }
        .frame(height: 26)
    }
}
