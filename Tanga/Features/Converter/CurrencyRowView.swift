import SwiftUI

struct CurrencyRowView: View {
    let code: String
    let currency: Currency?
    let isActive: Bool
    /// Основная валюта из настроек: от неё считаются тренды остальных строк.
    let isBase: Bool
    let amount: String
    /// Подставленное значение выделено — первая цифра его заменит.
    let isSelected: Bool
    /// «= 1 234,00» под выражением, если в нём есть оператор.
    let result: String?
    /// Цена валюты в основной за неделю; у основной строки и пока история не загрузилась — nil.
    let trend: Trend?
    var onTap: () -> Void
    var onPick: () -> Void
    var onChart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CurrencyBadge(code: code, currency: currency)

            Button(action: onPick) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(code)
                            .font(.system(size: 21))
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(currency?.name ?? " ")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 120, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 6)

            amountView
                .layoutPriority(1)

            chartButton
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 66)
        .background(isActive ? Theme.rowActive : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var amountView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 1) {
                Text(amount)
                    .font(.system(size: 25, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textPrimary.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, isActive && isSelected ? 3 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive && isSelected ? Theme.accent.opacity(0.28) : .clear)
                    )
                if isActive && !isSelected {
                    Caret()
                }
            }
            if isActive, let result {
                Text(result)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else if !isActive, let trend {
                Text(Self.changeText(trend.change))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Self.color(for: trend.change))
                    .lineLimit(1)
            }
        }
    }

    /// Мини-график за неделю вместо иконки; нажатие открывает полный график.
    /// У основной строки тренда нет, но место той же ширины остаётся — суммы в столбце не съезжают.
    @ViewBuilder private var chartButton: some View {
        if isBase {
            Color.clear.frame(width: Self.slotWidth, height: 48)
        } else {
            Button(action: onChart) {
                Group {
                    if let trend {
                        Sparkline(points: trend.points)
                            .stroke(Self.color(for: trend.change),
                                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 26, height: 13)
                    } else {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    }
                }
                .frame(width: Self.slotWidth, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("График \(code)")
            .accessibilityValue(trend.map { "За неделю \(Self.changeText($0.change))" } ?? "")
        }
    }

    private static let slotWidth: CGFloat = 36

    /// Меньше 0,005% — считаем, что курс стоит на месте.
    private static func isFlat(_ change: Double) -> Bool { abs(change) < 0.00005 }

    static func changeText(_ change: Double) -> String {
        let percent = abs(change).formatted(.percent.precision(.fractionLength(2)))
        if isFlat(change) { return percent }
        return (change > 0 ? "▲ " : "▼ ") + percent
    }

    private static func color(for change: Double) -> Color {
        if isFlat(change) { return Theme.textSecondary }
        return change > 0 ? Theme.positive : Theme.danger
    }
}

/// Линия по точкам, растянутая на всю рамку по обеим осям.
nonisolated private struct Sparkline: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1, let low = points.min(), let high = points.max() else { return path }
        let frame = rect.insetBy(dx: 1, dy: 1.5)
        let span = high - low
        for (index, value) in points.enumerated() {
            let x = frame.minX + frame.width * CGFloat(index) / CGFloat(points.count - 1)
            let t = span > 0 ? (value - low) / span : 0.5
            let point = CGPoint(x: x, y: frame.maxY - frame.height * CGFloat(t))
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

/// Мигающий курсор в активной строке.
private struct Caret: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Theme.accent)
            .frame(width: 2, height: 26)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
