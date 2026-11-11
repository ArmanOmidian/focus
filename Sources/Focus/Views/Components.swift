import SwiftUI

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
    @Environment(\.palette) private var p
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
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
    @Environment(\.palette) private var p
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
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
        }
    }
}

struct DuePopover: View {
    let task: TaskItem
    let close: () -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.palette) private var p

    private var current: Date { task.due ?? DueFormat.suggested() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                quick("Today", days: 0)
                quick("Tomorrow", days: 1)
                quick("Next week", days: 7)
            }

            DatePicker("", selection: Binding(
                get: { current },
                set: { set(DueFormat.combine(day: $0, time: current)) }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Time").font(.jakarta(12))
                Spacer()
                DatePicker("", selection: Binding(
                    get: { current },
                    set: { set(DueFormat.combine(day: current, time: $0)) }
                ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)
                .labelsHidden()
            }

            HStack {
                if task.due != nil {
                    Button("Remove") {
                        store.update(task.id) { $0.due = nil }
                        close()
                    }
                    .foregroundStyle(p.danger)
                } else {
                    Text("You’ll get a notification.")
                        .font(.jakarta(11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    if task.due == nil { set(current) }
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .font(.jakarta(12))
        }
        .padding(14)
        .frame(width: 260)
    }

    private func set(_ date: Date) {
        store.update(task.id) { $0.due = date }
    }

    private func quick(_ title: String, days: Int) -> some View {
        Button(title) {
            let cal = Calendar.current
            let day = cal.date(byAdding: .day, value: days, to: Date()) ?? Date()
            set(DueFormat.combine(day: day, time: current))
        }
        .controlSize(.small)
    }
}
