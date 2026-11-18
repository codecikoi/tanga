import Charts
import SwiftUI

@Observable
final class RateChartModel {
    var base: String
    var quote: String
    var range: ChartRange = .month
    private(set) var points: [RatePoint] = []
    private(set) var isLoading = false

    @ObservationIgnored private let history: HistoryRepository

    init(base: String, quote: String, history: HistoryRepository) {
        self.base = base
        self.quote = quote
        self.history = history
    }

    var taskKey: String { "\(base)-\(quote)-\(range.rawValue)" }

    func swap() {
        (base, quote) = (quote, base)
    }

    /// Дневная история + текущий живой курс последней точкой.
    func load(live: Double?) async {
        isLoading = true
        var loaded = await history.series(base: base, quote: quote, range: range)
        guard !Task.isCancelled else { return }
        if let live, live.isFinite, live > 0 {
            loaded.removeAll { Date.now.timeIntervalSince($0.date) < 12 * 3600 }
            loaded.append(RatePoint(date: .now, value: live))
        }
        points = loaded
        isLoading = false
    }
}

struct RateChartView: View {
    @Environment(ConverterStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model: RateChartModel
    @State private var selectedDate: Date?

    init(base: String, quote: String, history: HistoryRepository) {
        _model = State(initialValue: RateChartModel(base: base, quote: quote, history: history))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pairHeader
                    valueHeader
                    Picker("Период", selection: $model.range) {
                        ForEach(ChartRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    chart
                        .frame(height: 260)
                    stats
                    Text("История — дневные курсы Currency API, последняя точка — текущий курс.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("График курса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .task(id: model.taskKey) {
                selectedDate = nil
                await model.load(live: liveRate)
            }
        }
    }

    private var liveRate: Double? {
        guard let base = store.rate(model.base), let quote = store.rate(model.quote) else { return nil }
        return quote / base
    }

    // MARK: - Заголовки

    private var pairHeader: some View {
        HStack(spacing: 10) {
            CurrencyBadge(code: model.base, currency: store.currency(model.base))
            Text(model.base).font(.title3.weight(.semibold))
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
            CurrencyBadge(code: model.quote, currency: store.currency(model.quote))
            Text(model.quote).font(.title3.weight(.semibold))
            Spacer()
            Button {
                withAnimation(.snappy) { model.swap() }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("Поменять местами")
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private var valueHeader: some View {
        let shown = selectedPoint ?? model.points.last
        return VStack(alignment: .leading, spacing: 4) {
            Text("1 \(model.base) =")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(shown.map { AmountFormatter.rate($0.value) } ?? liveRate.map { AmountFormatter.rate($0) } ?? "—")
                    .font(.system(size: 36, weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(model.quote)
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
            }
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            if let selectedPoint {
                Text(selectedPoint.date.formatted(date: .long, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } else if let change {
                Text(changeText(change))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(change.absolute >= 0 ? Theme.positive : Theme.danger)
            }
        }
    }

    // MARK: - График

    private var chart: some View {
        let points = model.points
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.15, abs(high) * 0.002)
        let domain = (low - padding)...(high + padding)
        let color = (change?.absolute ?? 0) >= 0 ? Theme.positive : Theme.danger

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Дата", point.date),
                    yStart: .value("Минимум", domain.lowerBound),
                    yEnd: .value("Курс", point.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.32), color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)

                LineMark(x: .value("Дата", point.date), y: .value("Курс", point.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let selectedPoint {
                RuleMark(x: .value("Дата", selectedPoint.date))
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(x: .value("Дата", selectedPoint.date), y: .value("Курс", selectedPoint.value))
                    .foregroundStyle(color)
                    .symbolSize(80)
            }
        }
        .chartYScale(domain: domain)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.separator)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(AmountFormatter.rate(number))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.separator)
                AxisValueLabel(format: axisFormat)
            }
        }
        .overlay {
            if model.isLoading && points.isEmpty {
                ProgressView()
            } else if !model.isLoading && points.count < 2 {
                ContentUnavailableView("Нет истории", systemImage: "chart.line.downtrend.xyaxis",
                                       description: Text("Для этой пары нет дневных архивов."))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: points)
    }

    private var axisFormat: Date.FormatStyle {
        switch model.range {
        case .week, .month: .dateTime.day().month(.abbreviated)
        case .quarter, .year: .dateTime.month(.abbreviated)
        case .twoYears: .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private var selectedPoint: RatePoint? {
        guard let selectedDate else { return nil }
        return model.points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    // MARK: - Сводка

    private var change: (absolute: Double, percent: Double)? {
        guard let first = model.points.first?.value, let last = model.points.last?.value, first > 0,
              model.points.count > 1
        else { return nil }
        return (last - first, (last - first) / first * 100)
    }

    private func changeText(_ change: (absolute: Double, percent: Double)) -> String {
        let sign = change.absolute >= 0 ? "+" : "−"
        let percent = abs(change.percent).formatted(.number.precision(.fractionLength(2)))
        return "\(sign)\(AmountFormatter.rate(abs(change.absolute))) (\(sign)\(percent)%) за \(model.range.title)"
    }

    private var stats: some View {
        let values = model.points.map(\.value)
        return HStack(spacing: 10) {
            statCard("Минимум", values.min())
            statCard("Максимум", values.max())
            statCard("Среднее", values.isEmpty ? nil : values.reduce(0, +) / Double(values.count))
        }
    }

    private func statCard(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value.map { AmountFormatter.rate($0) } ?? "—")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
