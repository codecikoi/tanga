import Foundation
import Testing
@testable import Tanga

struct TrendTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ daysAgo: Int, _ rates: [String: Double]) -> (date: Date, rates: [String: Double]) {
        (now.addingTimeInterval(-Double(daysAgo) * 86_400), rates)
    }

    @Test func priceIsInBaseCurrencyAndEndsWithLiveRate() throws {
        // Курсы — единиц за 1 USD. Евро дорожает: за 1 EUR дают всё больше UZS.
        let days = [
            day(3, ["UZS": 12_000, "EUR": 0.96]),
            day(2, ["UZS": 12_000, "EUR": 0.95]),
            day(1, ["UZS": 12_000, "EUR": 0.94]),
        ]
        let trend = try #require(Trend.make(code: "EUR", base: "UZS", days: days,
                                            live: ["UZS": 12_000, "EUR": 0.93], now: now))
        #expect(trend.points.count == 4)
        #expect(abs(trend.points[0] - 12_500) < 1e-6)
        #expect(abs(trend.points[3] - 12_000 / 0.93) < 1e-6)
        #expect(trend.isUp)
        #expect(abs(trend.change - (0.96 / 0.93 - 1)) < 1e-9)
    }

    @Test func baseRowHasNoTrend() {
        let days = [day(2, ["USD": 1]), day(1, ["USD": 1])]
        #expect(Trend.make(code: "USD", base: "USD", days: days, live: ["USD": 1], now: now) == nil)
    }

    @Test func todaysDailyFileIsSkippedInFavourOfLiveRate() throws {
        let days = [
            day(2, ["UZS": 12_000, "USD": 1]),
            day(1, ["UZS": 12_100, "USD": 1]),
            (now.addingTimeInterval(-3600), ["UZS": 99_999, "USD": 1]),
        ]
        let trend = try #require(Trend.make(code: "USD", base: "UZS", days: days,
                                            live: ["UZS": 12_200, "USD": 1], now: now))
        #expect(trend.points == [12_000, 12_100, 12_200])
    }

    @Test func tooFewPointsGiveNoTrend() {
        let days = [day(1, ["UZS": 12_000, "USD": 1])]
        #expect(Trend.make(code: "USD", base: "UZS", days: days, live: ["UZS": 12_000, "USD": 1], now: now) == nil)
    }
}
