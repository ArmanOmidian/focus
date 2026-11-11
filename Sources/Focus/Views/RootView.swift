import SwiftUI

struct RootView: View {
    @EnvironmentObject private var ui: UIState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.forScheme(scheme)
        ZStack {
            p.background.ignoresSafeArea()
            if ui.showSettings {
                SettingsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: ui.showSettings)
        .environment(\.palette, p)
        .font(.jakarta(13))
        .foregroundStyle(p.text)
    }
}

struct MainView: View {
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var p

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus")
                        .font(.jakarta(20, .semibold))
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.jakarta(12))
                        .foregroundStyle(p.muted)
                }
                Spacer()
                IconButton(systemName: "gearshape", help: "Settings (⌘,)") { ui.showSettings = true }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)

            TimerCard()
                .padding(.horizontal, 20)
                .padding(.top, 16)

            AddTaskField()
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 6)

            TaskListView()
        }
    }
}
