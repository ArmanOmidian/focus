import AppKit
import SwiftUI
import Combine

/// Menu bar app:
/// - Click the menu bar icon to show / hide the window. Right-click it for more options.
/// - Closing the window only hides it. The app keeps running (timer + reminders keep working).
/// - No Dock icon, ever. Quit from the menu bar icon's right-click menu (or ⌘Q while the window is focused).
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) weak var shared: AppDelegate?

    let store = Store()
    let ui = UIState()
    lazy var timer = PomodoroTimer(store: store)

    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var purgeTimer: Timer?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Fonts.register()
        buildMainMenu()
        makeWindow()
        makeStatusItem()
        Notifier.shared.setup(store: store)

        // Theme
        store.$data.map(\.settings.theme).removeDuplicates()
            .sink { [weak self] in self?.apply(theme: $0) }
            .store(in: &cancellables)

        // Countdown in the menu bar
        timer.objectWillChange.merge(with: store.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &cancellables)

        // Delete expired completed tasks every 30 minutes
        let t = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in self?.store.purgeExpired() }
        RunLoop.main.add(t, forMode: .common)
        purgeTimer = t

        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Opening Focus again from Finder / Spotlight shows the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: Window

    private func makeWindow() {
        let root = RootView()
            .environmentObject(store)
            .environmentObject(ui)
            .environmentObject(timer)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 680),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.contentViewController = hosting
        w.setContentSize(NSSize(width: 420, height: 680))
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.title = "Focus"
        w.minSize = NSSize(width: 360, height: 480)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.collectionBehavior = [.moveToActiveSpace]
        w.center()
        w.setFrameAutosaveName("FocusMainWindow")
        window = w
    }

    /// The red button hides the window instead of closing it.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        store.purgeExpired()
    }

    func hideWindow() {
        window.orderOut(nil)
    }

    private func toggleWindow() {
        if window.isVisible && window.isKeyWindow && NSApp.isActive {
            hideWindow()
        } else {
            showWindow()
        }
    }

    // MARK: Menu bar icon

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Focus")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        button.toolTip = "Focus"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        let show = store.data.settings.showTimerInMenuBar && timer.state != .idle
        let title = show ? " " + timer.display : ""
        if button.title != title { button.title = title }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            toggleWindow()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(item("Open Focus", #selector(menuOpen)))
        menu.addItem(item("New Task", #selector(menuNewTask)))
        menu.addItem(.separator())
        let timerTitle: String
        switch timer.state {
        case .idle: timerTitle = "Start Timer (\(timer.durationMinutes)m)"
        case .running: timerTitle = "Pause Timer"
        case .paused: timerTitle = "Resume Timer"
        }
        menu.addItem(item(timerTitle, #selector(menuToggleTimer)))
        if timer.state != .idle { menu.addItem(item("Reset Timer", #selector(menuResetTimer))) }
        let flows = store.flowsToday
        let flowsItem = NSMenuItem(title: flows == 1 ? "1 flow today" : "\(flows) flows today", action: nil, keyEquivalent: "")
        flowsItem.isEnabled = false
        menu.addItem(flowsItem)
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(menuSettings)))
        menu.addItem(item("Quit Focus", #selector(menuQuit), key: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)   // opens the menu under the icon
        statusItem.menu = nil                  // so a normal left-click toggles the window again
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func menuOpen() { showWindow() }

    @objc func menuNewTask() {
        ui.showSettings = false
        showWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.ui.focusAddField += 1 }
    }

    @objc private func menuToggleTimer() { timer.toggle() }
    @objc private func menuResetTimer() { timer.reset() }

    @objc func menuSettings() {
        ui.showSettings = true
        showWindow()
    }

    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuHide() { hideWindow() }

    // MARK: Keyboard shortcuts (menu is hidden for menu bar apps, but shortcuts still work)

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("Settings…", #selector(menuSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit Focus", #selector(menuQuit), key: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(item("New Task", #selector(menuNewTask), key: "n"))
        fileMenu.addItem(item("Close Window", #selector(menuHide), key: "w"))
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        // Edit menu: needed for copy / paste / undo inside text fields.
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    // MARK: Theme

    private func apply(theme: AppTheme) {
        switch theme {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }
}
