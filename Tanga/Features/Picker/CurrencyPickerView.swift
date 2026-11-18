import SwiftUI

/// Выбор валюты: все валюты мира, криптовалюты и драгметаллы с поиском.
struct CurrencyPickerView: View {
    enum Mode {
        /// Добавление в список — можно отметить несколько.
        case add
        /// Замена валюты в строке — выбор одной.
        case replace(String)
        /// Выбор одной валюты для настройки или графика; в список она не добавляется.
        case choose(title: String, selected: String, onSelect: (String) -> Void)
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all, fiat, crypto, metal

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "Все"
            case .fiat: "Валюты"
            case .crypto: "Крипто"
            case .metal: "Металлы"
            }
        }

        func includes(_ kind: CurrencyKind) -> Bool {
            switch self {
            case .all: true
            case .fiat: kind == .fiat
            case .crypto: kind == .crypto
            case .metal: kind == .metal
            }
        }
    }

    let mode: Mode
    @Environment(ConverterStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter: Filter = .all

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    ForEach(searchResults) { row($0) }
                } else {
                    if filter == .all {
                        Section("Популярные") {
                            ForEach(CurrencyCatalog.popular.compactMap(store.currency)) { row($0) }
                        }
                    }
                    ForEach(CurrencyKind.allCases.filter(filter.includes), id: \.self) { kind in
                        let items = store.currencies.filter { $0.kind == kind }
                        if !items.isEmpty {
                            Section("\(kind.title) · \(items.count)") {
                                ForEach(items) { row($0) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Код или название")
            .autocorrectionDisabled()
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Тип", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .overlay {
                if isSearching && searchResults.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: "Добавить валюту"
        case .replace(let code): "Заменить \(code)"
        case .choose(let title, _, _): title
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Точное совпадение кода — первым, затем коды с таким началом, затем названия
    /// (популярные выше: по «вона» южнокорейская раньше северокорейской).
    private var searchResults: [Currency] {
        let needle = CurrencyCatalog.fold(query.trimmingCharacters(in: .whitespaces))
        let upper = needle.uppercased()
        return store.currencies
            .filter { filter.includes($0.kind) && $0.searchKey.contains(needle) }
            .sorted { lhs, rhs in
                let l = score(lhs, upper), r = score(rhs, upper)
                return l != r ? l < r : CurrencyCatalog.order(lhs, rhs)
            }
    }

    private func score(_ currency: Currency, _ code: String) -> Int {
        if currency.code == code { return 0 }
        if currency.code.hasPrefix(code) { return 1 }
        return CurrencyCatalog.popular.contains(currency.code) ? 2 : 3
    }

    private func isChecked(_ currency: Currency) -> Bool {
        switch mode {
        case .add: store.codes.contains(currency.code)
        case .replace(let code): currency.code == code
        case .choose(_, let selected, _): currency.code == selected
        }
    }

    private func row(_ currency: Currency) -> some View {
        Button { select(currency) } label: {
            HStack(spacing: 12) {
                CurrencyBadge(code: currency.code, currency: currency)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code)
                        .font(.headline)
                    Text(currency.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let price = usdPrice(currency) {
                    Text(price)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isChecked(currency) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked(currency) ? Theme.accent : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Цена в долларах для крипты и металлов.
    private func usdPrice(_ currency: Currency) -> String? {
        guard currency.kind != .fiat, let rate = store.rate(currency.code) else { return nil }
        return "$" + AmountFormatter.rate(1 / rate)
    }

    private func select(_ currency: Currency) {
        switch mode {
        case .add:
            if store.codes.contains(currency.code) {
                store.remove(currency.code)
            } else {
                store.add(currency.code)
            }
        case .replace(let code):
            store.replace(code, with: currency.code)
            dismiss()
        case .choose(_, _, let onSelect):
            onSelect(currency.code)
            dismiss()
        }
    }
}
