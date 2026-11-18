import Foundation

enum AmountFormatter {
    private static var cache: [String: NumberFormatter] = [:]

    /// Авто-точность: копейки для сумм от 1, четыре значащие цифры для мелочи (0,001517 BTC).
    nonisolated static func autoFractionDigits(_ value: Double) -> Int {
        let magnitude = abs(value)
        guard magnitude.isFinite, magnitude > 0 else { return 0 }
        if magnitude >= 1 { return 2 }
        return min(12, max(2, -Int(floor(log10(magnitude))) + 3))
    }

    /// Точность для курса «1 X = … Y».
    nonisolated static func rateFractionDigits(_ value: Double) -> Int {
        let magnitude = abs(value)
        guard magnitude.isFinite, magnitude > 0 else { return 2 }
        if magnitude >= 100 { return 2 }
        if magnitude >= 1 { return 4 }
        return min(12, -Int(floor(log10(magnitude))) + 3)
    }

    static func digits(for value: Double, precision: DisplayPrecision) -> Int {
        precision.fixedDigits ?? autoFractionDigits(value)
    }

    /// Сумма для экрана: `1 172 084,21`.
    static func string(_ value: Double, precision: DisplayPrecision, locale: Locale = .current) -> String {
        let digits = digits(for: value, precision: precision)
        return formatter(digits: digits, grouping: true, locale: locale)
            .string(from: NSNumber(value: normalized(value, digits: digits))) ?? "—"
    }

    /// Сумма для подстановки в калькулятор: `1172084.21`, без хвостовых нулей.
    static func plain(_ value: Double, precision: DisplayPrecision) -> String {
        let digits = digits(for: value, precision: precision)
        let formatter = formatter(digits: digits, grouping: false, locale: Locale(identifier: "en_US_POSIX"))
        var text = formatter.string(from: NSNumber(value: normalized(value, digits: digits))) ?? "0"
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }

    static func rate(_ value: Double, locale: Locale = .current) -> String {
        let digits = rateFractionDigits(value)
        return formatter(digits: digits, grouping: true, locale: locale)
            .string(from: NSNumber(value: normalized(value, digits: digits))) ?? "—"
    }

    /// Убирает «-0,00» у крошечных отрицательных значений.
    private static func normalized(_ value: Double, digits: Int) -> Double {
        abs(value) < 0.5 * pow(10, -Double(digits)) ? 0 : value
    }

    private static func formatter(digits: Int, grouping: Bool, locale: Locale) -> NumberFormatter {
        let key = "\(locale.identifier)|\(digits)|\(grouping)"
        if let cached = cache[key] { return cached }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.roundingMode = .halfUp
        cache[key] = formatter
        return formatter
    }
}
