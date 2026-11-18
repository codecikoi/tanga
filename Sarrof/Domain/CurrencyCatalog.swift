import Foundation

nonisolated struct CryptoInfo: Codable, Hashable, Sendable {
    var name: String
    var color: String?
    var rank: Int
}

/// Справочные данные о валютах: названия и цвета криптомонет.
nonisolated struct CurrencyMetadata: Codable, Sendable {
    /// Криптовалюты из списка Coinbase, ключ — код в верхнем регистре.
    var crypto: [String: CryptoInfo]
    /// Английские названия из Currency API, ключ — код в верхнем регистре.
    var names: [String: String]
    var fetchedAt: Date

    static let empty = CurrencyMetadata(crypto: [:], names: [:], fetchedAt: .distantPast)
}

nonisolated enum CurrencyCatalog {
    static let popular = [
        "USD", "EUR", "RUB", "UZS", "KZT", "KGS", "TJS", "TRY", "CNY", "KRW",
        "JPY", "GBP", "AED", "BTC", "ETH", "USDT", "XAU",
    ]

    private static let metalNames: [String: String] = [
        "XAU": "Золото, тройская унция",
        "XAG": "Серебро, тройская унция",
        "XPT": "Платина, тройская унция",
        "XPD": "Палладий, тройская унция",
    ]

    private static let extraNames: [String: String] = [
        "GGP": "Гернсийский фунт",
        "IMP": "Мэнский фунт",
        "JEP": "Джерсийский фунт",
        "TVD": "Доллар Тувалу",
        "KID": "Доллар Кирибати",
        "FOK": "Фарерская крона",
        "XDR": "СДР (МВФ)",
    ]

    static func build(codes: some Sequence<String>, meta: CurrencyMetadata, locale: Locale = .current) -> [Currency] {
        let english = Locale(identifier: "en_US")
        let cryptoCodes = Set(meta.crypto.keys)
        var result: [Currency] = []

        for code in Set(codes) {
            guard let kind = CurrencyClassifier.kind(of: code, cryptoCodes: cryptoCodes) else { continue }
            let apiName = meta.names[code].flatMap { $0.isEmpty ? nil : $0 }
            var englishName = apiName ?? ""
            let name: String

            switch kind {
            case .metal:
                name = metalNames[code] ?? apiName ?? code
            case .fiat:
                englishName = english.localizedString(forCurrencyCode: code) ?? englishName
                name = extraNames[code]
                    ?? locale.localizedString(forCurrencyCode: code).map(capitalizingFirst)
                    ?? apiName
                    ?? code
            case .crypto:
                name = meta.crypto[code]?.name ?? apiName ?? code
            }

            result.append(Currency(
                code: code,
                name: name,
                kind: kind,
                colorHex: meta.crypto[code]?.color,
                rank: kind == .crypto ? (meta.crypto[code]?.rank ?? 1_000_000) : 0,
                searchKey: fold("\(code) \(name) \(englishName)")
            ))
        }
        return result.sorted(by: order)
    }

    static func order(_ a: Currency, _ b: Currency) -> Bool {
        if a.kind != b.kind { return a.kind.sortIndex < b.kind.sortIndex }
        if a.kind == .metal {
            return (CurrencyClassifier.metals.firstIndex(of: a.code) ?? 0) < (CurrencyClassifier.metals.firstIndex(of: b.code) ?? 0)
        }
        if a.rank != b.rank { return a.rank < b.rank }
        return a.code < b.code
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private static func capitalizingFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
