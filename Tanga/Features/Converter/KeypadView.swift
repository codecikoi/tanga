import SwiftUI

/// Клавиатура-калькулятор: C · 7 8 9 / ⟳ · 4 5 6 / ±×÷ · 1 2 3 / 0 , ⌫
struct KeypadView: View {
    var isRefreshing: Bool
    var onKey: (KeypadKey) -> Void

    private let spacing: CGFloat = 10
    private let keyHeight: CGFloat = 58
    private let decimalSeparator = Locale.current.decimalSeparator ?? ","

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            VStack(spacing: spacing) {
                key(.clear) {
                    Text("C")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.danger)
                }
                key(.refresh) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.rotate, options: .repeat(.continuous), isActive: isRefreshing)
                }
                OperatorPad(onKey: onKey)
                    .frame(height: keyHeight * 2 + spacing)
            }
            VStack(spacing: spacing) {
                digit(7)
                digit(4)
                digit(1)
                digit(0)
            }
            VStack(spacing: spacing) {
                digit(8)
                digit(5)
                digit(2)
                key(.decimal) {
                    Text(decimalSeparator)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            VStack(spacing: spacing) {
                digit(9)
                digit(6)
                digit(3)
                key(.backspace) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textPrimary)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in onKey(.clear) }
                )
            }
        }
    }

    private func digit(_ value: Int) -> some View {
        key(.digit(value)) {
            Text("\(value)")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func key<Label: View>(_ key: KeypadKey, @ViewBuilder label: () -> Label) -> some View {
        let content = label()
        return Button { onKey(key) } label: { content }
            .buttonStyle(KeyStyle())
            .frame(height: keyHeight)
    }
}

/// Высокая клавиша с четырьмя операторами.
private struct OperatorPad: View {
    var onKey: (KeypadKey) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                button(.add)
                button(.subtract)
            }
            GridRow {
                button(.multiply)
                button(.divide)
            }
        }
        .padding(6)
        .background(shape.fill(Theme.key))
        .overlay(shape.strokeBorder(Theme.keyBorder, lineWidth: 1))
    }

    private func button(_ op: CalcOperator) -> some View {
        Button { onKey(.op(op)) } label: {
            Text(op.symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(OperatorStyle())
        .accessibilityLabel(op.symbol)
    }
}

private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(configuration.isPressed ? Theme.keyPressed : Theme.key))
            .overlay(shape.strokeBorder(Theme.keyBorder, lineWidth: 1))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OperatorStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? Theme.keyPressed : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
