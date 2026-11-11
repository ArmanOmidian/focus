# Focus

A minimal to-do list and pomodoro timer that lives in the macOS menu bar.

- **Tasks:** type in *Add a task* and press Enter. Double-click a task to rename it. Drag tasks to reorder them.
- **Priority tags:** High, Medium or Low. Click the tag to change it.
- **Due date and time:** click the calendar icon on a task (it appears on hover). You get a notification at the due time, or earlier if you change it in Settings.
- **Completed:** checking a task strikes it through and drops it into *Completed*. Click *Completed* to open it. From there you can restore a task, delete it, or clear everything. Completed tasks are deleted automatically after 7 days (changeable in Settings).
- **Pomodoro timer:** drag the ruler or pick a preset (5m / 25m / 15m), then click *start*. A soft chime plays when time is up. The countdown also shows in the menu bar.
- **Menu bar app:** click the icon in the menu bar to open or hide Focus. Right-click it for New Task, the timer, Settings and Quit. Closing the window only hides it, and Focus never shows in the Dock.
- **Settings** (gear icon or `⌘,`): timer lengths, auto-switch between focus and break, sound and volume, reminder timing, how long to keep completed tasks, appearance, open at login.

Shortcuts: `⌘N` new task · `⌘W` hide window · `⌘,` settings · `⌘Q` quit.

## Install

Requires macOS 14 or newer and Xcode.

```bash
git clone https://github.com/ArmanOmidian/focus.git
cd focus
./build-app.sh --install
```

To update after changing the code (or after `git pull`), run `./build-app.sh --install` again.
Your tasks are kept in `~/Library/Application Support/Focus/data.json`.

To edit and run in Xcode: `open Package.swift`, then ⌘R. Notifications only work in the installed app.

## Files

| File | What it does |
| --- | --- |
| `Sources/Focus/AppDelegate.swift` | Menu bar icon, window, hide-on-close, keyboard shortcuts |
| `Sources/Focus/Models.swift` | Task, priority, settings |
| `Sources/Focus/Store.swift` | Saving, adding, checking, reordering, auto-delete of completed tasks |
| `Sources/Focus/PomodoroTimer.swift` | Timer logic and the chime |
| `Sources/Focus/Notifier.swift` | Due-date and timer notifications |
| `Sources/Focus/Theme.swift` | Colors, font, date formatting |
| `Sources/Focus/Views/` | Main screen, timer card, task rows, settings |
| `Resources/` | App icon, chime sound, Plus Jakarta Sans font (SIL Open Font License) |
