import Foundation
import AppKit

/// The pomodoro timer. Keeps running while the window is hidden.
final class PomodoroTimer: ObservableObject {
    enum State { case idle, running, paused }

    @Published private(set) var state: State = .idle
    /// The length you picked (minutes).
    @Published private(set) var durationMinutes: Int
    /// Seconds left.
    @Published private(set) var remaining: TimeInterval

    private let store: Store
    private var endDate: Date?
    private var ticker: Timer?

    static let rulerMax = 60

    init(store: Store) {
        self.store = store
        let m = store.data.settings.focusMinutes
        durationMinutes = m
        remaining = TimeInterval(m * 60)
    }

    // MARK: Display

    var display: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Where the ruler indicator sits (minutes).
    var rulerValue: Double {
        state == .idle ? Double(durationMinutes) : remaining / 60
    }

    // MARK: Controls

    func setDuration(_ minutes: Int) {
        guard state == .idle else { return }
        let m = max(1, min(180, minutes))
        guard m != durationMinutes || remaining != TimeInterval(m * 60) else { return }
        durationMinutes = m
        remaining = TimeInterval(m * 60)
    }

    func start() {
        guard state != .running else { return }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        startTicker()
    }

    func pause() {
        guard state == .running else { return }
        tick()
        state = .paused
        stopTicker()
    }

    func reset() {
        stopTicker()
        state = .idle
        remaining = TimeInterval(durationMinutes * 60)
    }

    func toggle() {
        state == .running ? pause() : start()
    }

    // MARK: Ticking

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)   // keeps ticking while menus/drags are open
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard state == .running, let end = endDate else { return }
        let left = max(0, end.timeIntervalSinceNow)
        if Int(left.rounded(.up)) != Int(remaining.rounded(.up)) || left == 0 {
            remaining = left
        }
        if left <= 0 { finish() }
    }

    /// Anything that isn't one of the break lengths counts as a focus session.
    var isBreak: Bool {
        let s = store.data.settings
        return durationMinutes == s.shortBreakMinutes || durationMinutes == s.longBreakMinutes
    }

    private func finish() {
        stopTicker()
        let s = store.data.settings
        let wasFocus = !isBreak

        if wasFocus { store.recordFlow() }
        if s.soundEnabled { Chime.play(volume: s.soundVolume) }
        Notifier.shared.timerFinished(wasFocus: wasFocus, flowsToday: store.flowsToday)

        state = .idle
        if s.autoSwitchToBreak {
            if wasFocus {
                let every = max(1, s.longBreakEvery)
                let longBreak = store.flowsToday % every == 0
                durationMinutes = longBreak ? s.longBreakMinutes : s.shortBreakMinutes
            } else {
                durationMinutes = s.focusMinutes
            }
        }
        remaining = TimeInterval(durationMinutes * 60)
    }
}

// MARK: - Sound

enum Chime {
    private static var current: NSSound?

    static func play(volume: Double) {
        guard let url = Resources.url("chime", "wav"),
              let sound = NSSound(contentsOf: url, byReference: true) else {
            NSSound.beep()
            return
        }
        current?.stop()
        sound.volume = Float(max(0, min(1, volume)))
        current = sound
        sound.play()
    }
}
