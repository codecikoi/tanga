import Foundation

nonisolated enum CalcOperator: Character, CaseIterable, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"

    var symbol: String {
        switch self {
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        case .divide: "÷"
        }
    }
}

/// Строка калькулятора в активной строке конвертера.
///
/// Внутри хранится в «машинном» виде (`1172084.21+50`), на экран выводится
/// с разделителями текущей локали (`1 172 084,21 + 50`).
nonisolated struct CalcInput: Equatable, Sendable {
    private(set) var text: String
    /// Значение подставлено из другой строки и выделено: первая цифра его заменит.
    private(set) var replaceOnType: Bool

    static let maxLength = 40
    static let maxDigitsPerNumber = 15

    init(text: String = "0", replaceOnType: Bool = true) {
        self.text = text.isEmpty ? "0" : text
        self.replaceOnType = replaceOnType
    }

    var hasOperator: Bool {
        text.dropFirst().contains { CalcOperator(rawValue: $0) != nil }
    }

    // MARK: - Ввод

    mutating func digit(_ value: Int) {
        guard (0...9).contains(value) else { return }
        let char = Character(String(value))
        if replaceOnType {
            text = String(char)
            replaceOnType = false
            return
        }
        let number = lastNumber
        if number == "0" || number == "-0" {
            text.removeLast()
            text.append(char)
            return
        }
        guard text.count < Self.maxLength,
              number.filter(\.isNumber).count < Self.maxDigitsPerNumber
        else { return }
        text.append(char)
    }

    mutating func decimalPoint() {
        if replaceOnType {
            text = "0."
            replaceOnType = false
            return
        }
        let number = lastNumber
        guard !number.contains("."), text.count < Self.maxLength else { return }
        text.append(number.isEmpty ? "0." : ".")
    }

    mutating func apply(_ op: CalcOperator) {
        replaceOnType = false
        if text.last == "." { text.removeLast() }
        if endsWithOperator { text.removeLast() }
        guard text.count < Self.maxLength else { return }
        text.append(op.rawValue)
    }

    mutating func backspace() {
        replaceOnType = false
        text.removeLast()
        if text.isEmpty || text == "-" { text = "0" }
    }

    mutating func clear() {
        text = "0"
        replaceOnType = false
    }

    /// Подставляет значение из другой строки (при смене активной валюты).
    mutating func seed(_ plain: String) {
        text = plain.isEmpty ? "0" : plain
        replaceOnType = true
    }

    // MARK: - Вычисление

    /// Результат выражения; висящий в конце оператор игнорируется. `nil` — деление на ноль.
    var value: Double? {
        var tokens = Self.tokenize(text)
        if case .op = tokens.last { tokens.removeLast() }
        guard case .number(let first)? = tokens.first else { return nil }

        var sum = 0.0
        var term = first
        var sign = 1.0
        var index = 1
        while index + 1 < tokens.count {
            guard case .op(let op) = tokens[index], case .number(let number) = tokens[index + 1] else { return nil }
            switch op {
            case .multiply:
                term *= number
            case .divide:
                guard number != 0 else { return nil }
                term /= number
            case .add:
                sum += sign * term
                sign = 1
                term = number
            case .subtract:
                sum += sign * term
                sign = -1
                term = number
            }
            index += 2
        }
        let result = sum + sign * term
        return result.isFinite ? result : nil
    }

    // MARK: - Отображение

    func display(locale: Locale = .current) -> String {
        let decimal = locale.decimalSeparator ?? "."
        let grouping = locale.groupingSeparator ?? " "
        var output = ""
        var buffer = ""
        for (index, char) in text.enumerated() {
            if let op = CalcOperator(rawValue: char), !(index == 0 && op == .subtract) {
                output += Self.group(buffer, decimal: decimal, grouping: grouping)
                buffer = ""
                output += " \(op.symbol) "
            } else {
                buffer.append(char)
            }
        }
        output += Self.group(buffer, decimal: decimal, grouping: grouping)
        return output
    }

    // MARK: - Внутреннее

    private enum Token {
        case number(Double)
        case op(CalcOperator)
    }

    private var endsWithOperator: Bool {
        guard text.count > 1, let last = text.last else { return false }
        return CalcOperator(rawValue: last) != nil
    }

    /// Число, которое сейчас набирается (после последнего оператора).
    private var lastNumber: Substring {
        var start = text.endIndex
        while start > text.startIndex {
            let previous = text.index(before: start)
            let char = text[previous]
            if char.isNumber || char == "." {
                start = previous
            } else if char == "-" && previous == text.startIndex {
                start = previous
            } else {
                break
            }
        }
        return text[start...]
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""
        func flush() {
            guard !buffer.isEmpty else { return }
            let clean = buffer.hasSuffix(".") ? String(buffer.dropLast()) : buffer
            tokens.append(.number(Double(clean) ?? 0))
            buffer = ""
        }
        for (index, char) in text.enumerated() {
            if let op = CalcOperator(rawValue: char), !(index == 0 && op == .subtract) {
                flush()
                tokens.append(.op(op))
            } else {
                buffer.append(char)
            }
        }
        flush()
        return tokens
    }

    private static func group(_ number: String, decimal: String, grouping: String) -> String {
        guard !number.isEmpty else { return "" }
        var body = Substring(number)
        var sign = ""
        if body.first == "-" {
            sign = "−"
            body = body.dropFirst()
        }
        let parts = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        var grouped = ""
        for (index, digit) in parts[0].reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped.append(contentsOf: grouping.reversed()) }
            grouped.append(digit)
        }
        var result = sign + String(grouped.reversed())
        if parts.count > 1 { result += decimal + parts[1] }
        return result
    }
}
