import Foundation

/// Загружает курсы из Coinbase и Currency API, сводит их и хранит последний снимок на диске.
final class RatesRepository {
    private let http = HTTPClient()
    private let store = FileStore(.applicationSupportDirectory, folder: "Tanga")
    private let fileName = "rates.json"
    private static let metadataMaxAge: TimeInterval = 3 * 24 * 3600

    /// Последний сохранённый снимок, а при первом запуске — курсы, вшитые в приложение.
    func loadInitial() -> RatesData {
        if let cached = store.decode(RatesData.self, fileName), cached.rates.count > 1 {
            return cached
        }
        return Self.bundledSeed()
            ?? RatesData(rates: ["USD": 1], updatedAt: .distantPast, sources: [], meta: .empty)
    }

    func refresh(previous: RatesData) async throws -> RatesData {
        async let coinbase = try? fetchCoinbase()
        async let daily = try? fetchDaily()

        var meta = previous.meta
        if meta.crypto.isEmpty || Date.now.timeIntervalSince(meta.fetchedAt) > Self.metadataMaxAge,
           let fresh = try? await fetchMetadata() {
            meta = fresh
        }

        let live = await coinbase
        let reference = await daily
        guard live != nil || reference != nil else { throw RatesError.network }

        var sources: [RateSource] = []
        if live != nil { sources.append(.coinbase) }
        if reference != nil { sources.append(.currencyAPI) }

        let rates = RatesMerger.merge(
            coinbase: live,
            reference: reference ?? previous.rates,
            cryptoCodes: Set(meta.crypto.keys)
        )
        let data = RatesData(rates: rates, updatedAt: .now, sources: sources, meta: meta)
        store.encode(data, fileName)
        return data
    }

    // MARK: - Сеть

    private func fetchCoinbase() async throws -> [String: Double] {
        try RatesParser.coinbaseRates(await http.data(from: [Endpoints.coinbaseRates]))
    }

    private func fetchDaily() async throws -> [String: Double] {
        try RatesParser.fawazRates(await http.data(from: Endpoints.latestUSD)).rates
    }

    private func fetchMetadata() async throws -> CurrencyMetadata {
        async let cryptoData = http.data(from: [Endpoints.coinbaseCrypto])
        async let namesData = http.data(from: Endpoints.currencyNames)
        let crypto = try RatesParser.coinbaseCrypto(try await cryptoData)
        let names = (try? RatesParser.fawazNames(try await namesData)) ?? [:]
        return CurrencyMetadata(crypto: crypto, names: names, fetchedAt: .now)
    }

    // MARK: - Встроенные курсы

    /// Курсы на момент сборки — чтобы приложение работало даже при первом запуске без сети.
    static func bundledSeed() -> RatesData? {
        func load(_ name: String) -> Data? {
            Bundle.main.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        }
        guard let dailyData = load("seed-fawaz-usd"),
              let daily = try? RatesParser.fawazRates(dailyData)
        else { return nil }

        let crypto = load("seed-coinbase-crypto").flatMap { try? RatesParser.coinbaseCrypto($0) } ?? [:]
        let names = load("seed-fawaz-names").flatMap { try? RatesParser.fawazNames($0) } ?? [:]
        let live = load("seed-coinbase-rates").flatMap { try? RatesParser.coinbaseRates($0) }
        let meta = CurrencyMetadata(crypto: crypto, names: names, fetchedAt: .distantPast)

        return RatesData(
            rates: RatesMerger.merge(coinbase: live, reference: daily.rates, cryptoCodes: Set(crypto.keys)),
            updatedAt: daily.date.flatMap(DayKey.date(from:)) ?? .distantPast,
            sources: [.bundled],
            meta: meta
        )
    }
}
