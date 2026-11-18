import SwiftUI

struct ConverterView: View {
    @Environment(ConverterStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var route: Route?
    @State private var keypadVisible = true

    enum Route: Identifiable, Hashable {
        case settings, add, edit
        case replace(String)
        case chart(String)

        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.separator).frame(height: 1)
            rows
            bottomPanel
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $route) { route in
            sheet(for: route)
        }
        .onChange(of: settings.refreshInterval) {
            store.restartAutoRefresh()
        }
        #if DEBUG
        .task { applyDebugLaunchArguments() }
        #endif
    }

    #if DEBUG
    /// Сценарий для скриншотов из терминала, только в отладочной сборке:
    /// `xcrun simctl launch booted com.zoir.sarrof -debugActive CNY -debugKeys 650+100 -debugRoute chart:USD`
    private func applyDebugLaunchArguments() {
        let defaults = UserDefaults.standard
        if let code = defaults.string(forKey: "debugActive") { store.activate(code) }
        for char in defaults.string(forKey: "debugKeys") ?? "" {
            switch char {
            case "0"..."9": store.press(.digit(Int(String(char)) ?? 0))
            case ".": store.press(.decimal)
            case "<": store.press(.backspace)
            case "C": store.press(.clear)
            default: CalcOperator(rawValue: char).map { store.press(.op($0)) }
            }
        }
        guard let raw = defaults.string(forKey: "debugRoute") else { return }
        let parts = raw.split(separator: ":").map(String.init)
        switch parts.first {
        case "settings": route = .settings
        case "add": route = .add
        case "edit": route = .edit
        case "replace": route = .replace(parts.last ?? "USD")
        case "chart": route = .chart(parts.last ?? "USD")
        default: break
        }
    }
    #endif

    // MARK: - Шапка

    private var header: some View {
        HStack {
            Button { route = .settings } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Настройки")

            Spacer()

            HStack(spacing: 0) {
                Text("SAR").fontWeight(.light)
                Text("ROF").fontWeight(.heavy)
            }
            .font(.system(size: 21))
            .tracking(4)

            Spacer()

            Menu {
                Button("Добавить валюту", systemImage: "plus") { route = .add }
                Button("Изменить список", systemImage: "list.bullet") { route = .edit }
                Button("Обновить курсы", systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 23))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Ещё")
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 54)
    }

    // MARK: - Строки валют

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.codes, id: \.self) { code in
                        row(code, proxy: proxy)
                            .id(code)
                    }
                    Button { route = .add } label: {
                        Label("Добавить валюту", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.refresh() }
            .onChange(of: store.activeCode) { _, code in
                withAnimation { proxy.scrollTo(code) }
            }
        }
    }

    private func row(_ code: String, proxy: ScrollViewProxy) -> some View {
        let isActive = code == store.activeCode
        let input = store.input
        let result: String? = isActive && input.hasOperator
            ? input.value.map { "= " + AmountFormatter.string($0, precision: settings.precision) }
            : nil

        return CurrencyRowView(
            code: code,
            currency: store.currency(code),
            isActive: isActive,
            amount: isActive ? input.display() : store.formattedAmount(for: code),
            isSelected: input.replaceOnType,
            result: result,
            onTap: { activate(code, proxy: proxy) },
            onPick: { route = .replace(code) },
            onChart: { route = .chart(code) }
        )
        .contextMenu {
            Button("Скопировать сумму", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = isActive ? input.display() : store.formattedAmount(for: code)
            }
            Button("График курса", systemImage: "chart.xyaxis.line") { route = .chart(code) }
            Button("Заменить валюту", systemImage: "arrow.left.arrow.right") { route = .replace(code) }
            Divider()
            Button("Убрать из списка", systemImage: "trash", role: .destructive) {
                withAnimation { store.remove(code) }
            }
            .disabled(store.codes.count <= 1)
        }
    }

    private func activate(_ code: String, proxy: ScrollViewProxy) {
        Haptics.tap(settings.haptics)
        store.activate(code)
        if !keypadVisible {
            withAnimation(.snappy) { keypadVisible = true }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation { proxy.scrollTo(code) }
            }
        }
    }

    // MARK: - Клавиатура и статус

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.textSecondary.opacity(0.45))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { setKeypad(!keypadVisible) }
                .gesture(
                    DragGesture(minimumDistance: 8).onEnded { value in
                        if value.translation.height > 20 { setKeypad(false) }
                        if value.translation.height < -20 { setKeypad(true) }
                    }
                )
                .accessibilityLabel(keypadVisible ? "Скрыть клавиатуру" : "Показать клавиатуру")

            if keypadVisible {
                KeypadView(isRefreshing: store.isRefreshing) { key in
                    Haptics.tap(settings.haptics)
                    store.press(key)
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            StatusLine(
                data: store.data,
                isRefreshing: store.isRefreshing,
                failed: store.lastRefreshFailed,
                onTap: { Task { await store.refresh() } }
            )
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.18), radius: 14, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func setKeypad(_ visible: Bool) {
        guard visible != keypadVisible else { return }
        withAnimation(.snappy(duration: 0.3)) { keypadVisible = visible }
    }

    // MARK: - Экраны

    @ViewBuilder private func sheet(for route: Route) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .add:
            CurrencyPickerView(mode: .add)
        case .edit:
            EditListView()
        case .replace(let code):
            CurrencyPickerView(mode: .replace(code))
        case .chart(let code):
            let pair = store.chartPair(for: code)
            RateChartView(base: pair.base, quote: pair.quote, history: store.history)
        }
    }
}

/// Строка состояния под клавиатурой: когда обновились курсы и откуда.
private struct StatusLine: View {
    let data: RatesData
    let isRefreshing: Bool
    let failed: Bool
    var onTap: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dotColor(now: context.date))
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(sourcesText)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var statusText: String {
        if isRefreshing { return "Обновляем курсы…" }
        let time = formatted(data.updatedAt)
        if data.updatedAt == .distantPast { return "Нет данных о курсах" }
        if failed { return "Нет связи · курсы \(time)" }
        if data.sources == [.bundled] { return "Встроенные курсы \(time)" }
        return "Обновлено \(time)"
    }

    private var sourcesText: String {
        data.sources.filter { $0 != .bundled }.map(\.title).joined(separator: " · ")
    }

    private func dotColor(now: Date) -> Color {
        if failed { return Theme.danger }
        let fresh = data.sources.contains(.coinbase) && now.timeIntervalSince(data.updatedAt) < 300
        return fresh ? Theme.positive : Theme.gold
    }

    private func formatted(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "в " + date.formatted(date: .omitted, time: .shortened)
        }
        return "от " + date.formatted(.dateTime.day().month(.abbreviated))
    }
}
