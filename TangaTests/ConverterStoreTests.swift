import Foundation
import Testing
@testable import Tanga

@MainActor
struct ConverterStoreTests {
    private func makeStore() -> ConverterStore {
        let defaults = UserDefaults(suiteName: "tanga-tests-\(UUID().uuidString)")!
        return ConverterStore(settings: AppSettings(defaults: defaults), defaults: defaults)
    }

    private func type(_ keys: String, into store: ConverterStore) {
        for char in keys {
            if let digit = char.wholeNumberValue {
                store.press(.digit(digit))
            } else if let op = CalcOperator(rawValue: char) {
                store.press(.op(op))
            }
        }
    }

    /// Регрессия: раньше строка подхватывала округлённое значение, и после EUR → RUB → USD
    /// сумма в UZS менялась на десятки сумов (12 014 074 → 12 014 109).
    @Test func switchingRowsKeepsAmountsExact() throws {
        let store = makeStore()
        store.activate("USD")
        type("1000", into: store)
        let uzs = try #require(store.amount(for: "UZS"))

        for code in ["EUR", "RUB", "KRW", "EUR", "RUB", "BTC", "USD"] {
            store.activate(code)
            let now = try #require(store.amount(for: "UZS"))
            #expect(abs(now - uzs) < uzs * 1e-9, "UZS сдвинулся после \(code)")
        }
        #expect(store.input.text == "1000")
        #expect(abs(try #require(store.amount(for: "USD")) - 1000) < 1e-9)
    }

    @Test func typingAfterSwitchUsesTypedValue() throws {
        let store = makeStore()
        store.activate("USD")
        type("1000", into: store)
        store.activate("EUR")
        type("5", into: store)
        #expect(store.amount(for: "EUR") == 5)
    }

    @Test func finishEditingCollapsesExpression() {
        let store = makeStore()
        store.activate("USD")
        type("650+100*2", into: store)
        store.finishEditing()
        #expect(store.input.text == "850")
        #expect(store.input.replaceOnType)
        #expect(store.amount(for: "USD") == 850)
    }

    /// График из строки открывается против основной валюты, а не против активной строки.
    @Test func chartPairUsesMainCurrency() {
        let store = makeStore()
        store.settings.mainCurrency = "UZS"
        store.activate("RUB")
        #expect(store.chartPair(for: "EUR") == ("EUR", "UZS"))
        #expect(store.chartPair(for: "USD") == ("USD", "UZS"))
        // У самой основной — против соседней строки, курс ≥ 1.
        #expect(store.chartPair(for: "UZS") == ("USD", "UZS"))
    }

    @Test func choosingCurrencyOnOtherSideSwapsChartPair() {
        let model = RateChartModel(base: "RUB", quote: "UZS", history: HistoryRepository())
        model.set("UZS", for: .base)
        #expect(model.base == "UZS" && model.quote == "RUB")
        model.set("EUR", for: .quote)
        #expect(model.base == "UZS" && model.quote == "EUR")
    }
}
