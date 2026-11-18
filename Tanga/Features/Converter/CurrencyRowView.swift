import SwiftUI

struct CurrencyRowView: View {
    let code: String
    let currency: Currency?
    let isActive: Bool
    let amount: String
    /// Подставленное значение выделено — первая цифра его заменит.
    let isSelected: Bool
    /// «= 1 234,00» под выражением, если в нём есть оператор.
    let result: String?
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

            Button(action: onChart) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("График \(code)")
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
            }
        }
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
