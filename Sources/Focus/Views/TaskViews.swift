import SwiftUI

// MARK: - Add task

struct AddTaskField: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(focused ? p.text : p.muted)
            TextField("Add a task", text: $text)
                .textFieldStyle(.plain)
                .font(.jakarta(13))
                .focused($focused)
                .onSubmit {
                    withAnimation(.easeOut(duration: 0.2)) { store.add(text) }
                    text = ""
                    focused = true
                }
            if !text.isEmpty {
                Text("↵")
                    .font(.jakarta(12))
                    .foregroundStyle(p.faint)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(p.field))
        .onChange(of: ui.focusAddField) { _, _ in focused = true }
    }
}

// MARK: - List

struct TaskListView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var confirmClear = false

    var body: some View {
        let active = store.activeTasks
        let completed = store.completedTasks

        List {
            if active.isEmpty {
                Text(completed.isEmpty ? "Nothing here yet. Add your first task above." : "All done. Nice work.")
                    .font(.jakarta(12))
                    .foregroundStyle(p.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .modifier(PlainRow())
            }

            ForEach(active) { task in
                TaskRow(task: task)
                    .modifier(PlainRow())
            }
            .onMove { from, to in
                withAnimation(.easeOut(duration: 0.2)) { store.moveActive(from: from, to: to) }
            }

            if !completed.isEmpty {
                completedHeader(count: completed.count)
                    .padding(.top, 14)
                    .modifier(PlainRow())

                if ui.showCompleted {
                    ForEach(completed) { task in
                        CompletedRow(task: task)
                            .modifier(PlainRow())
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 10)
        .animation(.easeOut(duration: 0.2), value: ui.showCompleted)
        .confirmationDialog("Delete all completed tasks?", isPresented: $confirmClear) {
            Button("Delete All", role: .destructive) {
                withAnimation { store.clearCompleted() }
            }
        } message: {
            Text("This can’t be undone.")
        }
    }

    private func completedHeader(count: Int) -> some View {
        HStack(spacing: 8) {
            Button {
                ui.showCompleted.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(ui.showCompleted ? 90 : 0))
                        .frame(width: 16)
                    Text("Completed")
                        .font(.jakarta(12, .semibold))
                    Text("\(count)")
                        .font(.jakarta(12))
                        .foregroundStyle(p.faint)
                    Spacer()
                }
                .foregroundStyle(p.muted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if ui.showCompleted {
                Button("Clear all") { confirmClear = true }
                    .buttonStyle(.plain)
                    .font(.jakarta(12))
                    .foregroundStyle(p.muted)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
    }
}

/// Removes the default list row styling.
struct PlainRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Active row

struct TaskRow: View {
    let task: TaskItem

    @EnvironmentObject private var store: Store
    @Environment(\.palette) private var p
    @State private var hover = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        let done = task.completedAt != nil

        HStack(spacing: 10) {
            CheckBox(checked: done) {
                withAnimation(.easeOut(duration: 0.2)) { store.toggle(task.id) }
            }

            if editing {
                TextField("Task", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit(commit)
                    .onExitCommand { editing = false }
            } else {
                Text(task.title)
                    .strikethrough(done, color: p.faint)
                    .foregroundStyle(done ? p.faint : p.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { beginEdit() }
                    .help("Double-click to rename · drag to reorder")
            }

            DueButton(task: task, rowHover: hover)
                .opacity(done ? 0.5 : 1)
            PriorityPill(task: task)
                .opacity(done ? 0.5 : 1)
            IconButton(systemName: "trash", help: "Delete", destructive: true) {
                withAnimation(.easeOut(duration: 0.2)) { store.delete(task.id) }
            }
            .opacity(hover ? 1 : 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hover ? p.hover : Color.clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onChange(of: titleFocused) { _, focused in
            if !focused && editing { commit() }
        }
    }

    private func beginEdit() {
        draft = task.title
        editing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { titleFocused = true }
    }

    private func commit() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { store.update(task.id) { $0.title = t } }
        editing = false
    }
}

// MARK: - Completed row

struct CompletedRow: View {
    let task: TaskItem

    @EnvironmentObject private var store: Store
    @Environment(\.palette) private var p
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            CheckBox(checked: true) {
                withAnimation(.easeOut(duration: 0.2)) { store.toggle(task.id) }
            }
            .help("Restore task")

            Text(task.title)
                .strikethrough(true, color: p.faint)
                .foregroundStyle(p.faint)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(leftText)
                .font(.jakarta(11))
                .foregroundStyle(p.faint)
                .help("Completed tasks are deleted automatically")

            IconButton(systemName: "trash", help: "Delete now", destructive: true) {
                withAnimation(.easeOut(duration: 0.2)) { store.delete(task.id) }
            }
            .opacity(hover ? 1 : 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hover ? p.hover : Color.clear))
        .onHover { hover = $0 }
    }

    private var leftText: String {
        guard let exp = store.expiryDate(for: task) else { return "" }
        let hours = exp.timeIntervalSinceNow / 3600
        if hours < 1 { return "deleting soon" }
        if hours < 24 { return "\(Int(hours.rounded(.up)))h left" }
        return "\(Int((hours / 24).rounded(.up)))d left"
    }
}
