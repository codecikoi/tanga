import Foundation

nonisolated struct RatePoint: Identifiable, Hashable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }
}

nonisolated enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, quarter, year, twoYears

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "1Н"
        case .month: "1М"
        case .quarter: "3М"
        case .year: "1Г"
        case .twoYears: "2Г"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 91
        case .year: 365
        case .twoYears: 730
        }
    }

    /// Шаг между точками в днях — около 30 точек на любой период.
    var step: Int {
        switch self {
        case .week, .month: 1
        case .quarter: 3
        case .year: 12
        case .twoYears: 24
        }
    }
}

/// История курсов из дневных архивов Currency API.
///
/// Один файл дня содержит курсы всех ~340 валют к USD, поэтому любая пара строится
/// из тех же файлов. Прошлые дни не меняются — кэшируем их на диске навсегда.
final class HistoryRepository {
    /// Самый ранний архив в npm-пакете `@fawazahmed0/currency-api`.
    static let earliestDay = "2024-03-02"

    private let http = HTTPClient(timeout: 12)
    private let disk = FileStore(.cachesDirectory, folder: "Tanga/history")
    private var memory: [String: [String: Double]] = [:]
    private var inflight: [String: Task<[String: Double]?, Never>] = [:]
    private var failures: [String: Date] = [:]

    func series(base: String, quote: String, range: ChartRange, now: Date = .now) async -> [RatePoint] {
        await days(range: range, now: now).compactMap { day in
            guard let baseRate = day.rates[base], let quoteRate = day.rates[quote] else { return nil }
            return RatePoint(date: day.date, value: quoteRate / baseRate)
        }
    }

    /// Курсы всех валют к USD по дням периода, от старых к новым; дни, которые не загрузились, пропущены.
    func days(range: ChartRange, now: Date = .now) async -> [(date: Date, rates: [String: Double])] {
        let keys = Self.dayKeys(range: range, now: now)
        let loaded = await withTaskGroup(of: (String, [String: Double]?).self) { group in
            for key in keys {
                group.addTask { (key, await self.day(key)) }
            }
            var result: [String: [String: Double]] = [:]
            for await (key, rates) in group {
                if let rates { result[key] = rates }
            }
            return result
        }
        return keys.compactMap { key in
            guard let rates = loaded[key], let date = DayKey.date(from: key) else { return nil }
            return (date, rates)
        }
    }

    static func dayKeys(range: ChartRange, now: Date) -> [String] {
        var offsets = Array(stride(from: range.days, to: 0, by: -range.step))
        if offsets.last != 1 { offsets.append(1) }
        offsets.append(0)

        var seen = Set<String>()
        var keys: [String] = []
        for offset in offsets {
            guard let date = DayKey.calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = DayKey.string(from: date)
            if key >= earliestDay, seen.insert(key).inserted { keys.append(key) }
        }
        return keys
    }

    private func day(_ key: String) async -> [String: Double]? {
        if let cached = memory[key] { return cached }
        if let task = inflight[key] { return await task.value }
        if let failedAt = failures[key], Date.now.timeIntervalSince(failedAt) < 600 { return nil }

        if let data = disk.read("\(key).json"), let parsed = try? RatesParser.fawazRates(data) {
            memory[key] = parsed.rates
            return parsed.rates
        }

        // Отдельная задача: смена периода на графике не должна обрывать загрузку дня.
        let task = Task { [weak self] () -> [String: Double]? in
            guard let self else { return nil }
            guard let data = try? await self.http.data(from: Endpoints.usd(on: key)),
                  let parsed = try? RatesParser.fawazRates(data)
            else {
                self.failures[key] = .now
                return nil
            }
            self.disk.write(data, "\(key).json")
            self.memory[key] = parsed.rates
            return parsed.rates
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }
}
