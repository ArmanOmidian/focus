import SwiftUI
import AppKit

/// The pomodoro card: ruler (drag to set minutes), presets, start/pause, big countdown.
struct TimerCard: View {
    @EnvironmentObject private var timer: PomodoroTimer
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p

    private var presets: [(label: String, minutes: Int)] {
        let s = store.data.settings
        return [("Short break", s.shortBreakMinutes), ("Focus", s.focusMinutes), ("Long break", s.longBreakMinutes)]
    }

    var body: some View {
        let idle = timer.state == .idle

        VStack(alignment: .leading, spacing: 14) {
            Ruler(value: timer.rulerValue, enabled: idle) { minutes in
                if minutes != timer.durationMinutes {
                    timer.setDuration(minutes)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            .opacity(idle ? 1 : 0.75)

            HStack(spacing: 14) {
                ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                    Button {
                        timer.setDuration(preset.minutes)
                    } label: {
                        Text("\(preset.minutes)m")
                            .font(.jakarta(12, .medium))
                            .foregroundStyle(idle && timer.durationMinutes == preset.minutes ? p.text : p.muted)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!idle)
                    .help(preset.label)
                }
                Spacer()
                Button {
                    ui.showSettings = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(p.muted)
                        .frame(width: 22, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Timer settings")
            }

            HStack(alignment: .lastTextBaseline) {
                HStack(spacing: 14) {
                    switch timer.state {
                    case .idle:
                        TextButton("start") { timer.start() }
                    case .running:
                        TextButton("pause") { timer.pause() }
                        TextButton("reset", muted: true) { timer.reset() }
                    case .paused:
                        TextButton("resume") { timer.start() }
                        TextButton("reset", muted: true) { timer.reset() }
                    }
                }
                Spacer()
                Text(timer.display)
                    .font(.jakarta(46, .light))
                    .monospacedDigit()
                    .foregroundStyle(p.text)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.2), value: timer.display)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.border))
    }
}

/// Thin tick marks with a dark indicator. Drag across it to pick 1–60 minutes.
struct Ruler: View {
    let value: Double
    let enabled: Bool
    let onChange: (Int) -> Void

    @Environment(\.palette) private var p
    private let maxMinutes = Double(PomodoroTimer.rulerMax)

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let palette = p
            let current = min(max(value, 0), maxMinutes)
            let maxV = maxMinutes

            Canvas { ctx, size in
                let ticks = Int(maxV * 2)   // a tick every 30 seconds
                for i in 0...ticks {
                    let x = (CGFloat(i) / CGFloat(ticks)) * (size.width - 1) + 0.5
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 2))
                    path.addLine(to: CGPoint(x: x, y: size.height - 2))
                    ctx.stroke(path, with: .color(palette.tick), lineWidth: 1)
                }
                let ix = CGFloat(current / maxV) * (size.width - 2) + 1
                var indicator = Path()
                indicator.move(to: CGPoint(x: ix, y: 0))
                indicator.addLine(to: CGPoint(x: ix, y: size.height))
                ctx.stroke(indicator, with: .color(palette.text), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard enabled, width > 0 else { return }
                        let m = Int((g.location.x / width * maxV).rounded())
                        onChange(max(1, min(Int(maxV), m)))
                    }
            )
        }
        .frame(height: 28)
        .help(enabled ? String("Drag to set the time") : String())
    }
}

struct TextButton: View {
    let title: String
    var muted = false
    let action: () -> Void
    @Environment(\.palette) private var p
    @State private var hover = false

    init(_ title: String, muted: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.muted = muted
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.jakarta(13, .medium))
                .foregroundStyle(muted ? (hover ? p.text : p.muted) : p.text)
                .underline(hover && !muted, color: p.faint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
