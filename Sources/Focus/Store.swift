import SwiftUI

/// All tasks + settings. Saved to ~/Library/Application Support/Focus/data.json on every change.
final class Store: ObservableObject {
    @Published var data: AppData {
        didSet {
            save()
            Notifier.shared.scheduleSync(data)
        }
    }

    /// Tasks that were just checked: they stay in place (struck through) for a moment, then drop into Completed.
    @Published var justCompleted: Set<UUID> = []

    let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Focus", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let raw = try? Data(contentsOf: fileURL), let decoded = try? decoder.decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData.sample()
        }
        purgeExpired()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            print("Focus: could not save – \(error)")
        }
    }

    // MARK: Lists

    var activeTasks: [TaskItem] {
        data.tasks.filter { $0.completedAt == nil || justCompleted.contains($0.id) }
    }

    var completedTasks: [TaskItem] {
        data.tasks
            .filter { $0.completedAt != nil && !justCompleted.contains($0.id) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func task(_ id: UUID) -> TaskItem? { data.tasks.first { $0.id == id } }

    // MARK: Editing

    func add(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        data.tasks.insert(TaskItem(title: t), at: 0)   // new tasks go to the top
    }

    func update(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&data.tasks[i])
    }

    func delete(_ id: UUID) {
        data.tasks.removeAll { $0.id == id }
        justCompleted.remove(id)
    }

    /// Check / uncheck.
    func toggle(_ id: UUID) {
        guard let t = task(id) else { return }
        if t.completedAt == nil {
            update(id) { $0.completedAt = Date() }
            justCompleted.insert(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                withAnimation(.easeInOut(duration: 0.25)) { _ = self?.justCompleted.remove(id) }
            }
        } else if justCompleted.contains(id) {
            // Unchecked again before it dropped away.
            justCompleted.remove(id)
            update(id) { $0.completedAt = nil }
        } else {
            // Restored from Completed: back to the top of the list.
            guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
            var item = data.tasks.remove(at: i)
            item.completedAt = nil
            data.tasks.insert(item, at: 0)
        }
    }

    /// Drag & drop inside the active list.
    func moveActive(from source: IndexSet, to destination: Int) {
        var active = activeTasks
        active.move(fromOffsets: source, toOffset: destination)
        let activeIDs = Set(active.map(\.id))
        data.tasks = active + data.tasks.filter { !activeIDs.contains($0.id) }
    }

    func clearCompleted() {
        data.tasks.removeAll { $0.completedAt != nil && !justCompleted.contains($0.id) }
    }

    // MARK: Auto-delete

    func expiryDate(for task: TaskItem) -> Date? {
        guard let done = task.completedAt else { return nil }
        return done.addingTimeInterval(Double(data.settings.keepCompletedDays) * 86_400)
    }

    /// Removes completed tasks older than the "keep completed" setting (default 7 days).
    func purgeExpired() {
        let now = Date()
        let keep = data.tasks.filter { t in
            guard let exp = expiryDate(for: t) else { return true }
            return exp > now
        }
        if keep.count != data.tasks.count { data.tasks = keep }
    }
}

/// View-only state.
final class UIState: ObservableObject {
    @Published var showSettings = false
    @Published var showCompleted = false
    /// Incremented to put the cursor in the "Add a task" field.
    @Published var focusAddField = 0
}
