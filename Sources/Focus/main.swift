import AppKit

// Focus is a menu bar app: it never shows a Dock icon (LSUIElement in Info.plist,
// and .accessory activation policy when run from Xcode).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
