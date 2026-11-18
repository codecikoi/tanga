import Foundation

nonisolated enum CurrencyKind: String, Codable, Sendable, CaseIterable {
    case fiat, crypto, metal

    var title: String {
        switch self {
        case .fiat: "Валюты"
        case .crypto: "Криптовалюты"
        case .metal: "Драгметаллы"
        }
    }

    var sortIndex: Int {
        switch self {
        case .fiat: 0
        case .crypto: 1
        case .metal: 2
        }
    }
}

/// Валюта из каталога: фиат, криптовалюта или драгметалл.
nonisolated struct Currency: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let kind: CurrencyKind
    /// Фирменный цвет монеты (из Coinbase) — для заглушки, пока грузится иконка.
    let colorHex: String?
    /// Порядок популярности у криптовалют (меньше — выше).
    let rank: Int
    /// Код + локализованное и английское название, приведённые к нижнему регистру.
    let searchKey: String

    var id: String { code }
}

/// Сопоставление кода валюты и страны — для флагов.
nonisolated enum CurrencyRegion {
    private static let overrides: [String: String] = [
        "EUR": "EU", "ANG": "CW", "XCG": "CW", "XPF": "PF", "CNH": "CN",
        "GGP": "GG", "IMP": "IM", "JEP": "JE", "TVD": "TV", "KID": "KI", "FOK": "FO",
    ]
    private static let withoutFlag: Set<String> = ["XAF", "XOF", "XCD", "XDR", "XSU", "XUA"]
    private static let regions: Set<String> = Set(
        Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 }
    )

    static func region(for code: String) -> String? {
        if let region = overrides[code] { return region }
        if withoutFlag.contains(code) { return nil }
        let prefix = String(code.prefix(2))
        return regions.contains(prefix) ? prefix : nil
    }

    static func flagEmoji(_ region: String) -> String {
        var result = ""
        for scalar in region.uppercased().unicodeScalars {
            if let flag = Unicode.Scalar(127_397 + scalar.value) {
                result.unicodeScalars.append(flag)
            }
        }
        return result
    }
}

/// Определяет, к какому виду относится код: фиат, крипта, металл или устаревшая валюта.
nonisolated enum CurrencyClassifier {
    static let metals = ["XAU", "XAG", "XPT", "XPD"]
    static let metalSet = Set(metals)
    /// Действующие валюты, которых нет в списке ISO 4217 (местные фунты, офшорный юань, СДР).
    static let extraFiat: Set<String> = ["GGP", "IMP", "JEP", "TVD", "CNH", "XDR", "VED", "FOK", "KID"]
    /// Дубликаты и служебные тикеры.
    static let hidden: Set<String> = ["XBT", "ETH2", "REPV2", "WLUNA"]
    static let commonISO: Set<String> = Set(Locale.commonISOCurrencyCodes)
    static let allISO: Set<String> = Set(Locale.Currency.isoCurrencies.map(\.identifier))

    static func isFiatCode(_ code: String) -> Bool {
        commonISO.contains(code) || extraFiat.contains(code)
    }

    /// Код есть в ISO 4217, но валюта выведена из оборота (немецкая марка, песета…).
    static func isObsoleteISO(_ code: String) -> Bool {
        allISO.contains(code) && !isFiatCode(code) && !metalSet.contains(code)
    }

    /// `nil` — код не показываем (устаревшая валюта или служебный тикер).
    static func kind(of code: String, cryptoCodes: Set<String>) -> CurrencyKind? {
        if hidden.contains(code) { return nil }
        if metalSet.contains(code) { return .metal }
        if cryptoCodes.contains(code) { return .crypto }
        if isFiatCode(code) { return .fiat }
        if allISO.contains(code) { return nil }
        return .crypto
    }
}
