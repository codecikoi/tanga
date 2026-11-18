import Foundation

/// Недельный тренд валюты для мини-графика в строке: сколько она стоит в базовой валюте
/// (активной строке) по дням и насколько это изменилось.
nonisolated struct Trend: Equatable, Sendable {
    /// Цена 1 единицы валюты в базовой, от старых точек к новой.
    let points: [Double]
    /// Изменение за период: 0.012 = +1,2%.
    let change: Double

    var isUp: Bool { change >= 0 }

    /// Курсы в `days` и `live` — сколько единиц валюты дают за 1 USD.
    /// Последней точкой идёт живой курс; дневной файл за последние 12 часов
    /// пропускаем, чтобы он не дублировал её.
    static func make(
        code: String,
        base: String,
        days: [(date: Date, rates: [String: Double])],
        live: [String: Double],
        now: Date = .now
    ) -> Trend? {
        guard code != base else { return nil }

        func price(_ rates: [String: Double]) -> Double? {
            guard let b = rates[base], let c = rates[code], b > 0, c > 0 else { return nil }
            let value = b / c
            return value.isFinite ? value : nil
        }

        var points = days
            .filter { now.timeIntervalSince($0.date) >= 12 * 3600 }
            .compactMap { price($0.rates) }
        if let current = price(live) { points.append(current) }

        guard points.count >= 3, let first = points.first, let last = points.last else { return nil }
        return Trend(points: points, change: last / first - 1)
    }
}
