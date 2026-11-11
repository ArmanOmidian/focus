import SwiftUI
import AppKit
import CoreText

// MARK: - Colors

struct Palette {
    var background: Color
    var card: Color
    var border: Color
    var field: Color
    var hover: Color
    var text: Color
    var muted: Color
    var faint: Color
    var tick: Color
    var danger: Color

    static let light = Palette(
        background: .white,
        card: .white,
        border: Color(hex: "#EBEBEE"),
        field: Color(hex: "#F6F6F8"),
        hover: Color(hex: "#F6F6F8"),
        text: Color(hex: "#111113"),
        muted: Color(hex: "#7A7A82"),
        faint: Color(hex: "#B4B4BB"),
        tick: Color(hex: "#DCDCE1"),
        danger: Color(hex: "#E5484D")
    )

    static let dark = Palette(
        background: Color(hex: "#161618"),
        card: Color(hex: "#1D1D20"),
        border: Color(hex: "#2C2C31"),
        field: Color(hex: "#222226"),
        hover: Color(hex: "#232327"),
        text: Color(hex: "#F1F1F3"),
        muted: Color(hex: "#9A9AA2"),
        faint: Color(hex: "#5E5E66"),
        tick: Color(hex: "#3A3A40"),
        danger: Color(hex: "#FF6369")
    )

    static func forScheme(_ s: ColorScheme) -> Palette { s == .dark ? .dark : .light }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: String) {
        let s = hex.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Bundled files (fonts, sound)

enum Resources {
    /// Looks in the app bundle first, then in the repo's Resources folder (when running from Xcode).
    static func url(_ name: String, _ ext: String, subdirectory: String? = nil) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return u
        }
        var dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Sources/Focus
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Resources")
        if let subdirectory { dev.appendPathComponent(subdirectory) }
        dev.appendPathComponent("\(name).\(ext)")
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }
}

// MARK: - Font: Plus Jakarta Sans

enum Fonts {
    static func register() {
        for name in ["PlusJakartaSans-Light", "PlusJakartaSans-Regular", "PlusJakartaSans-Medium", "PlusJakartaSans-SemiBold"] {
            if let url = Resources.url(name, "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

extension Font {
    static func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light: name = "PlusJakartaSans-Light"
        case .medium: name = "PlusJakartaSans-Medium"
        case .semibold, .bold, .heavy, .black: name = "PlusJakartaSans-SemiBold"
        default: name = "PlusJakartaSans-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Due date text

enum DueFormat {
    static func label(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Today \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday \(time)" }
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: Date())
        let day = sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(day) \(time)"
    }

    /// Next full hour from now.
    static func suggested() -> Date {
        let cal = Calendar.current
        let next = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: cal.component(.hour, from: next), minute: 0, second: 0, of: next) ?? next
    }

    /// Keeps the day of `day` and the hour/minute of `time`.
    static func combine(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }
}
