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

// MARK: - List (with drag anywhere on a row to reorder)

struct TaskListView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var confirmClear = false

    // Drag state
    @State private var draggingID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var rowHeights: [UUID: CGFloat] = [:]
    private let spacing: CGFloat = 2

    var body: some View {
        let active = store.activeTasks
        let completed = store.completedTasks
        let ids = active.map(\.id)
        let target = targetIndex(ids)

        ScrollView {
            VStack(spacing: spacing) {
                if active.isEmpty {
                    Text(completed.isEmpty ? "Nothing here yet. Add your first task above." : "All done. Nice work.")
                        .font(.jakarta(12))
                        .foregroundStyle(p.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }

                ForEach(Array(active.enumerated()), id: \.element.id) { index, task in
                    let isDragging = draggingID == task.id
                    TaskRow(
                        task: task,
                        isDragging: isDragging,
                        onDragChanged: { dy in
                            ui.dragLock = true
                            if draggingID == nil { draggingID = task.id }
                            if draggingID == task.id { dragOffset = dy }
                        },
                        onDragEnded: { finishDrag(ids) }
                    )
                    .background(GeometryReader { g in
                        Color.clear
                            .onAppear { rowHeights[task.id] = g.size.height }
                            .onChange(of: g.size.height) { _, h in rowHeights[task.id] = h }
                    })
                    .offset(y: isDragging ? dragOffset : shift(for: index, ids: ids, target: target))
                    .zIndex(isDragging ? 1 : 0)
                    .animation(isDragging ? nil : .easeOut(duration: 0.18), value: target)
                }

                if !completed.isEmpty {
                    completedHeader(count: completed.count)
                        .padding(.top, 14)

                    if ui.showCompleted {
                        ForEach(completed) { task in
                            CompletedRow(task: task)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.never)
        .animation(.easeOut(duration: 0.2), value: ui.showCompleted)
        .confirmationDialog("Delete all completed tasks?", isPresented: $confirmClear) {
            Button("Delete All", role: .destructive) {
                withAnimation { store.clearCompleted() }
            }
        } message: {
            Text("This can’t be undone.")
        }
    }

    // MARK: Drag maths

    private func height(_ id: UUID) -> CGFloat { (rowHeights[id] ?? 40) + spacing }

    /// Where the dragged row would land right now.
    private func targetIndex(_ ids: [UUID]) -> Int? {
        guard let id = draggingID, let from = ids.firstIndex(of: id) else { return nil }
        var target = from
        if dragOffset > 0 {
            var passed: CGFloat = 0
            for j in (from + 1)..<max(from + 1, ids.count) {
                let h = height(ids[j])
                if dragOffset > passed + h / 2 { target = j; passed += h } else { break }
            }
        } else if dragOffset < 0 {
            var passed: CGFloat = 0
            for j in stride(from: from - 1, through: 0, by: -1) {
                let h = height(ids[j])
                if -dragOffset > passed + h / 2 { target = j; passed += h } else { break }
            }
        }
        return target
    }

    /// Other rows slide out of the way.
    private func shift(for index: Int, ids: [UUID], target: Int?) -> CGFloat {
        guard let target, let id = draggingID, let from = ids.firstIndex(of: id) else { return 0 }
        let h = height(id)
        if from < target, index > from, index <= target { return -h }
        if target < from, index >= target, index < from { return h }
        return 0
    }

    private func finishDrag(_ ids: [UUID]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { ui.dragLock = false }
        guard let id = draggingID, let from = ids.firstIndex(of: id) else { return }
        let target = targetIndex(ids) ?? from
        withAnimation(.easeOut(duration: 0.2)) {
            if target != from {
                store.moveActive(from: IndexSet(integer: from), to: target > from ? target + 1 : target)
            }
            draggingID = nil
            dragOffset = 0
        }
    }

    // MARK: Completed header

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

// MARK: - Active row

struct TaskRow: View {
    let task: TaskItem
    let isDragging: Bool
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void

    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var hover = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        let done = task.completedAt != nil

        HStack(spacing: 10) {
            CheckBox(checked: done) {
                guard !ui.dragLock else { return }
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
            }

            DueButton(task: task, rowHover: hover && !isDragging)
                .opacity(done ? 0.5 : 1)
            PriorityPill(task: task)
                .opacity(done ? 0.5 : 1)
            IconButton(systemName: "trash", help: "Delete", destructive: true) {
                guard !ui.dragLock else { return }
                withAnimation(.easeOut(duration: 0.2)) { store.delete(task.id) }
            }
            .opacity(hover && !isDragging ? 1 : 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isDragging ? p.card : (hover ? p.hover : Color.clear))
                .shadow(color: .black.opacity(isDragging ? 0.12 : 0), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isDragging ? p.border : Color.clear)
        )
        .scaleEffect(isDragging ? 1.015 : 1)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        // Press anywhere on the row and drag to reorder (not while renaming).
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { onDragChanged($0.translation.height) }
                .onEnded { _ in onDragEnded() },
            including: editing ? .subviews : .all
        )
        .help("Drag to reorder · double-click to rename")
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
