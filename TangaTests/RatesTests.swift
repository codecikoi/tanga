import Foundation
import Testing
@testable import Tanga

struct RatesMergerTests {
    @Test func staleFiatFromCoinbaseIsRejected() {
        let rates = RatesMerger.merge(
            coinbase: ["MNT": 2623.5, "UZS": 12030],
            reference: ["MNT": 3606, "UZS": 12006],
            cryptoCodes: ["BTC"]
        )
        #expect(rates["MNT"] == 3606)
        #expect(rates["UZS"] == 12030)
    }

    @Test func cryptoAlwaysTakesLiveRate() {
        let rates = RatesMerger.merge(coinbase: ["BTC": 0.0000155], reference: ["BTC": 0.000014], cryptoCodes: ["BTC"])
        #expect(rates["BTC"] == 0.0000155)
    }

    @Test func obsoleteCurrencyDoesNotShadowCoin() {
        // ESP в дневном архиве — испанская песета, а в Coinbase — монета Espresso.
        let rates = RatesMerger.merge(coinbase: nil, reference: ["ESP": 151], cryptoCodes: ["ESP"])
        #expect(rates["ESP"] == nil)
    }

    @Test func usdIsAlwaysOne() {
        #expect(RatesMerger.merge(coinbase: ["USD": 0.99], reference: nil, cryptoCodes: [])["USD"] == 1)
    }

    @Test func parsesCoinbaseStrings() throws {
        let json = #"{"data":{"currency":"USD","rates":{"BTC":"0.0000155","uzs":"12030","BAD":"x","ZERO":"0"}}}"#
        let rates = try RatesParser.coinbaseRates(Data(json.utf8))
        #expect(rates == ["BTC": 0.0000155, "UZS": 12030])
    }

    @Test func parsesCurrencyAPI() throws {
        let json = #"{"date":"2026-11-17","usd":{"uzs":12006.5,"btc":1.5e-05}}"#
        let parsed = try RatesParser.fawazRates(Data(json.utf8))
        #expect(parsed.date == "2026-11-17")
        #expect(parsed.rates["UZS"] == 12006.5)
    }

    @Test func bundledSeedLoads() throws {
        let seed = try #require(RatesRepository.bundledSeed())
        #expect(seed.rates.count > 300)
        #expect(seed.rates["UZS"] != nil)
        #expect(seed.meta.crypto["BTC"]?.name == "Bitcoin")
    }
}

struct CatalogTests {
    @Test func classification() {
        #expect(CurrencyClassifier.kind(of: "UZS", cryptoCodes: []) == .fiat)
        #expect(CurrencyClassifier.kind(of: "BTC", cryptoCodes: ["BTC"]) == .crypto)
        #expect(CurrencyClassifier.kind(of: "XAU", cryptoCodes: []) == .metal)
        #expect(CurrencyClassifier.kind(of: "DEM", cryptoCodes: []) == nil)
        #expect(CurrencyClassifier.kind(of: "GGP", cryptoCodes: []) == .fiat)
    }

    @Test func regions() {
        #expect(CurrencyRegion.region(for: "UZS") == "UZ")
        #expect(CurrencyRegion.region(for: "EUR") == "EU")
        #expect(CurrencyRegion.region(for: "XAF") == nil)
        #expect(CurrencyRegion.flagEmoji("UZ") == "🇺🇿")
    }

    @Test func catalogCoversWholeWorld() throws {
        let seed = try #require(RatesRepository.bundledSeed())
        let catalog = CurrencyCatalog.build(codes: seed.rates.keys, meta: seed.meta)
        let fiat = catalog.filter { $0.kind == .fiat }
        let crypto = catalog.filter { $0.kind == .crypto }
        #expect(fiat.count >= 155)
        #expect(crypto.count >= 400)
        #expect(catalog.filter { $0.kind == .metal }.count == 4)
        #expect(!catalog.contains { $0.code == "DEM" })
    }
}

struct FormatterTests {
    @Test func autoDigits() {
        #expect(AmountFormatter.autoFractionDigits(97.52) == 2)
        #expect(AmountFormatter.autoFractionDigits(0.001517) == 6)
        #expect(AmountFormatter.autoFractionDigits(0) == 0)
    }

    @Test func plainSeedValue() {
        #expect(AmountFormatter.plain(650, precision: .auto) == "650")
        #expect(AmountFormatter.plain(1_172_084.214, precision: .auto) == "1172084.21")
        #expect(AmountFormatter.plain(0.00151723, precision: .auto) == "0.001517")
    }

    @Test func historyDayKeys() throws {
        let now = try #require(DayKey.date(from: "2026-11-18"))
        let keys = HistoryRepository.dayKeys(range: .week, now: now)
        #expect(keys.first == "2026-11-11")
        #expect(keys.last == "2026-11-18")
        #expect(keys.count == 8)
    }
}
