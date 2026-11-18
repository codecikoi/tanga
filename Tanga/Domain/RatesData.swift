import Foundation

nonisolated enum RateSource: String, Codable, Sendable {
    case coinbase, currencyAPI, bundled

    var title: String {
        switch self {
        case .coinbase: "Coinbase"
        case .currencyAPI: "Currency API"
        case .bundled: "встроенные"
        }
    }
}

/// Снимок курсов: сколько единиц валюты дают за 1 USD.
nonisolated struct RatesData: Codable, Sendable {
    var rates: [String: Double]
    var updatedAt: Date
    var sources: [RateSource]
    var meta: CurrencyMetadata
}

nonisolated enum RatesError: Error {
    case badFormat
    case network
}

/// Сводит курсы из двух источников.
///
/// Coinbase обновляется ежеминутно, но у редких фиатных валют там бывают
/// устаревшие значения (MNT, SSP). Поэтому фиат из Coinbase берём, только если он
/// расходится с дневным курсом Currency API не больше чем на `fiatTolerance`.
nonisolated enum RatesMerger {
    static let fiatTolerance = 0.03

    static func merge(coinbase: [String: Double]?, reference: [String: Double]?, cryptoCodes: Set<String>) -> [String: Double] {
        var result: [String: Double] = [:]

        for (code, value) in reference ?? [:] where value.isFinite && value > 0 {
            // Тикер монеты совпадает с кодом старой валюты (ESP — песета и Espresso):
            // дневной курс тут про песету, поэтому доверяем только Coinbase.
            if cryptoCodes.contains(code) && CurrencyClassifier.isObsoleteISO(code) { continue }
            result[code] = value
        }

        for (code, value) in coinbase ?? [:] where value.isFinite && value > 0 {
            let isFiat = CurrencyClassifier.isFiatCode(code) && !cryptoCodes.contains(code)
            if isFiat, let known = result[code], abs(value / known - 1) > fiatTolerance { continue }
            result[code] = value
        }

        result["USD"] = 1
        return result
    }
}

/// Разбор ответов API. JSONSerialization вместо Codable: форматы рыхлые,
/// значения бывают строками и числами, а лишние поля игнорируем.
nonisolated enum RatesParser {
    /// `{"data": {"currency": "USD", "rates": {"BTC": "0.0000155", ...}}}`
    static func coinbaseRates(_ data: Data) throws -> [String: Double] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rates = payload["rates"] as? [String: Any]
        else { throw RatesError.badFormat }
        return positiveNumbers(rates)
    }

    /// `{"date": "2026-11-17", "usd": {"uzs": 12006.5, ...}}`
    static func fawazRates(_ data: Data) throws -> (date: String?, rates: [String: Double]) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = root["usd"] as? [String: Any]
        else { throw RatesError.badFormat }
        return (root["date"] as? String, positiveNumbers(rates))
    }

    /// `{"usd": "US Dollar", "btc": "Bitcoin", ...}`
    static func fawazNames(_ data: Data) throws -> [String: String] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RatesError.badFormat
        }
        var names: [String: String] = [:]
        for (code, value) in root {
            if let name = value as? String, !name.isEmpty { names[code.uppercased()] = name }
        }
        return names
    }

    /// `{"data": [{"code": "BTC", "name": "Bitcoin", "color": "#F7931A", "sort_index": 100}, ...]}`
    static func coinbaseCrypto(_ data: Data) throws -> [String: CryptoInfo] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["data"] as? [[String: Any]]
        else { throw RatesError.badFormat }
        var result: [String: CryptoInfo] = [:]
        for (index, item) in items.enumerated() {
            guard let code = (item["code"] as? String)?.uppercased(), !code.isEmpty else { continue }
            let rank = (item["sort_index"] as? NSNumber)?.intValue ?? (10_000 + index)
            result[code] = CryptoInfo(
                name: item["name"] as? String ?? code,
                color: item["color"] as? String,
                rank: rank
            )
        }
        guard !result.isEmpty else { throw RatesError.badFormat }
        return result
    }

    private static func positiveNumbers(_ raw: [String: Any]) -> [String: Double] {
        var result: [String: Double] = [:]
        for (code, value) in raw {
            let number: Double?
            if let string = value as? String {
                number = Double(string)
            } else {
                number = (value as? NSNumber)?.doubleValue
            }
            if let number, number.isFinite, number > 0 {
                result[code.uppercased()] = number
            }
        }
        return result
    }
}

/// Ключ дня `yyyy-MM-dd` в UTC — так датированы архивы Currency API.
nonisolated enum DayKey {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static func string(from date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 1970)-\(pad(parts.month ?? 1))-\(pad(parts.day ?? 1))"
    }

    static func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
