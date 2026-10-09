import SwiftUI

/// Classic Sky guide palette: deep royal blue with Sky yellow highlights.
enum Theme {
    static let backgroundTop = Color(hex: "00135C")
    static let backgroundBottom = Color(hex: "0038A8")
    static let glow = Color(hex: "1D63E6")
    /// Sky yellow – focus highlight, channel numbers and accents.
    static let accent = Color(hex: "FFD100")
    /// Used for progress bars and the "now" line.
    static let live = Color(hex: "FFD100")
    /// Dark navy text on yellow.
    static let ink = Color(hex: "001450")
    static let panel = Color(hex: "0A2C8F").opacity(0.85)
    static let cell = Color(hex: "1E50C8").opacity(0.75)
    static let cellNow = Color(hex: "2E6BF0").opacity(0.9)
    static let secondaryText = Color(hex: "BCD0FF")

    // Layout metrics tuned for a 1920×1080 tvOS canvas.
    static let sidebarWidth: CGFloat = 340
    static let channelColumnWidth: CGFloat = 270
    static let rowHeight: CGFloat = 66
    static let rowSpacing: CGFloat = 8
    static let heroHeight: CGFloat = 300
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }
}

/// UK style date and time formatting ("7:30pm", "1h 30m", "Tomorrow").
enum Fmt {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let longDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static func range(_ programme: Programme) -> String {
        "\(time(programme.start)) – \(time(programme.end))"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func day(_ date: Date, relativeTo now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow" }
        return dayFormatter.string(from: date)
    }

    static func longDay(_ date: Date) -> String { longDayFormatter.string(from: date) }

    static func remaining(_ programme: Programme, at now: Date) -> String {
        "\(duration(programme.end.timeIntervalSince(now))) left"
    }
}
