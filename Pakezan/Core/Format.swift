import Foundation

enum Format {
    /// 1GB 以上は GB (10GB 未満は小数 2 桁)、それより少なければ MB で出す
    static func bytes(_ value: Double) -> String {
        let gb = value / Plan.bytesPerGB
        if gb >= 10 { return String(format: "%.1fGB", gb) }
        if gb >= 1 { return String(format: "%.2fGB", gb) }
        return String(format: "%.0fMB", value / 1_000_000)
    }

    static func gb(_ value: Double) -> Double { value / Plan.bytesPerGB }

    /// 「11月2日」
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month(.defaultDigits).day())
    }

    /// 「10/25 18:00」
    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month(.defaultDigits).day().hour().minute())
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}
