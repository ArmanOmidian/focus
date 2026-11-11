import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private var s: Binding<AppSettings> { $store.data.settings }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                IconButton(systemName: "chevron.left", help: "Back") { ui.showSettings = false }
                Text("Settings").font(.jakarta(17, .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsSection("Timer") {
                        SettingsRow("Focus") { minutes(s.focusMinutes) }
                        Divider()
                        SettingsRow("Short break") { minutes(s.shortBreakMinutes) }
                        Divider()
                        SettingsRow("Long break") { minutes(s.longBreakMinutes) }
                        Divider()
                        SettingsRow("Long break after every") {
                            Stepper(value: s.longBreakEvery, in: 2...8) {
                                Text("\(store.data.settings.longBreakEvery) flows")
                                    .font(.jakarta(12))
                                    .monospacedDigit()
                            }
                        }
                        Divider()
                        SettingsRow("Flows today: \(store.flowsToday)") {
                            Button("Reset") { store.resetTodayFlows() }
                                .disabled(store.flowsToday == 0)
                        }
                        Divider()
                        SettingsRow("Switch between focus and break automatically") {
                            Toggle("", isOn: s.autoSwitchToBreak).toggleStyle(.switch).labelsHidden().controlSize(.small)
                        }
                        Divider()
                        SettingsRow("Show countdown in the menu bar") {
                            Toggle("", isOn: s.showTimerInMenuBar).toggleStyle(.switch).labelsHidden().controlSize(.small)
                        }
                    }

                    SettingsSection("Sound") {
                        SettingsRow("Play a chime when time is up") {
                            Toggle("", isOn: s.soundEnabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
                        }
                        Divider()
                        SettingsRow("Volume") {
                            HStack(spacing: 8) {
                                Slider(value: s.soundVolume, in: 0...1)
                                    .frame(width: 110)
                                    .controlSize(.small)
                                IconButton(systemName: "play.fill", help: "Preview") {
                                    Chime.play(volume: store.data.settings.soundVolume)
                                }
                            }
                        }
                    }

                    SettingsSection("Reminders") {
                        SettingsRow("Notify me about due tasks") {
                            Toggle("", isOn: s.notificationsEnabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
                        }
                        Divider()
                        SettingsRow("When") {
                            Picker("", selection: s.reminder) {
                                ForEach(ReminderOffset.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        Divider()
                        SettingsRow("Test notification") {
                            Button("Send") { Notifier.shared.sendTest() }
                                .disabled(!Notifier.shared.isAvailable)
                        }
                    }

                    SettingsSection("Completed tasks") {
                        SettingsRow("Delete automatically after") {
                            Stepper(value: s.keepCompletedDays, in: 1...60) {
                                Text("\(store.data.settings.keepCompletedDays) \(store.data.settings.keepCompletedDays == 1 ? "day" : "days")")
                                    .font(.jakarta(12))
                                    .monospacedDigit()
                            }
                        }
                    }

                    SettingsSection("General") {
                        SettingsRow("Appearance") {
                            Picker("", selection: s.theme) {
                                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 170)
                        }
                        Divider()
                        SettingsRow("Open at login") {
                            Toggle("", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                        }
                        if let loginError {
                            Text(loginError)
                                .font(.jakarta(11))
                                .foregroundStyle(p.danger)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                        }
                    }

                    HStack {
                        Text("Data: ~/Library/Application Support/Focus")
                            .font(.jakarta(11))
                            .foregroundStyle(p.faint)
                        Spacer()
                        Button("Quit Focus") { NSApp.terminate(nil) }
                            .font(.jakarta(12))
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onExitCommand { ui.showSettings = false }
    }

    // MARK: Helpers

    private func minutes(_ value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...180) {
            Text("\(value.wrappedValue) min")
                .font(.jakarta(12))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn’t change this. Install Focus in Applications first."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Building blocks

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var p

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.jakarta(10.5, .semibold))
                .tracking(0.6)
                .foregroundStyle(p.faint)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(p.card))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.border))
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: () -> Control

    init(_ title: String, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.control = control
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.jakarta(13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
