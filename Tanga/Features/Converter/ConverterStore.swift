import SwiftUI

enum KeypadKey: Hashable {
    case digit(Int)
    case decimal
    case op(CalcOperator)
    case backspace
    case clear
    case refresh
}

/// Состояние конвертера: выбранные валюты, активная строка, ввод и курсы.
@Observable
final class ConverterStore {
    private(set) var data: RatesData
    private(set) var currencies: [Currency] = []
    private(set) var isRefreshing = false
    private(set) var lastRefreshFailed = false
    /// Дневные курсы за неделю для мини-графиков в строках.
    private(set) var week: [(date: Date, rates: [String: Double])] = []

    private(set) var codes: [String] {
        didSet { defaults.set(codes, forKey: Keys.codes) }
    }
    private(set) var activeCode: String {
        didSet { defaults.set(activeCode, forKey: Keys.active) }
    }
    private(set) var input: CalcInput {
        didSet { defaults.set(input.text, forKey: Keys.input) }
    }
    /// Точная сумма активной строки, пока её не начали править. В `input` лежит округлённый
    /// текст для экрана; если считать от него, каждое переключение строк сдвигало бы все суммы.
    private var exactValue: Double?

    let settings: AppSettings
    let history = HistoryRepository()

    @ObservationIgnored private var currencyByCode: [String: Currency] = [:]
    @ObservationIgnored private let repository: RatesRepository
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var autoRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var catalogSignature = ""

    static let defaultCodes = ["UZS", "USD", "EUR", "RUB", "KRW", "CNY", "BTC"]

    init(settings: AppSettings, repository: RatesRepository = RatesRepository(), defaults: UserDefaults = .standard) {
        self.settings = settings
        self.repository = repository
        self.defaults = defaults
        data = repository.loadInitial()

        let saved = defaults.stringArray(forKey: Keys.codes) ?? []
        let codes = saved.isEmpty ? Self.defaultCodes : saved
        self.codes = codes
        let active = defaults.string(forKey: Keys.active) ?? "USD"
        activeCode = codes.contains(active) ? active : codes[0]
        input = CalcInput(text: defaults.string(forKey: Keys.input) ?? "100", replaceOnType: true)
        rebuildCatalog()
    }

    // MARK: - Чтение

    func currency(_ code: String) -> Currency? { currencyByCode[code] }

    func rate(_ code: String) -> Double? { data.rates[code] }

    /// Сколько стоит введённая сумма в валюте `code`.
    func amount(for code: String) -> Double? {
        guard let value = activeValue else { return nil }
        if code == activeCode { return value }
        guard let from = data.rates[activeCode], let to = data.rates[code] else { return nil }
        return value / from * to
    }

    func formattedAmount(for code: String) -> String {
        guard let amount = amount(for: code) else { return "—" }
        return AmountFormatter.string(amount, precision: settings.precision)
    }

    /// Как за неделю изменилась цена `code` в основной валюте из настроек.
    /// От активной строки не зависит: иначе каждое нажатие на сумму перекрашивало бы все тренды.
    func trend(for code: String) -> Trend? {
        Trend.make(code: code, base: settings.mainCurrency, days: week, live: data.rates)
    }

    /// Пара для графика: валюта строки против основной, а у самой основной — против соседней строки.
    /// Курс показываем так, чтобы он был ≥ 1 (1 USD = 12 006 UZS, а не наоборот).
    func chartPair(for code: String) -> (base: String, quote: String) {
        let main = settings.mainCurrency
        let fallback = code == "USD" ? "EUR" : "USD"
        let other = code == main ? (codes.first { $0 != code } ?? fallback) : main
        guard let a = rate(code), let b = rate(other) else { return (code, other) }
        return b / a >= 1 ? (code, other) : (other, code)
    }

    var isLive: Bool {
        data.sources.contains(.coinbase) && Date.now.timeIntervalSince(data.updatedAt) < 600
    }

    // MARK: - Ввод

    /// Сумма в активной валюте: точная, если строку только выбрали, иначе — по введённому выражению.
    private var activeValue: Double? {
        if input.replaceOnType, let exactValue { return exactValue }
        return input.value
    }

    func activate(_ code: String) {
        guard code != activeCode, codes.contains(code) else { return }
        seed(amount(for: code))
        activeCode = code
    }

    /// Ввод закончен (клавиатуру спрятали): выражение сворачивается в итог, готовый к замене.
    func finishEditing() {
        guard !input.replaceOnType || input.hasOperator else { return }
        seed(activeValue)
    }

    func press(_ key: KeypadKey) {
        switch key {
        case .digit(let digit): input.digit(digit)
        case .decimal: input.decimalPoint()
        case .op(let op): input.apply(op)
        case .backspace: input.backspace()
        case .clear: input.clear()
        case .refresh:
            Task { await refresh() }
            return
        }
        exactValue = nil
    }

    private func seed(_ value: Double?) {
        exactValue = value
        input.seed(value.map { AmountFormatter.plain($0, precision: settings.precision) } ?? "0")
    }

    // MARK: - Список валют

    func add(_ code: String) {
        guard !codes.contains(code) else { return }
        codes.append(code)
    }

    func remove(_ code: String) {
        guard codes.count > 1, let index = codes.firstIndex(of: code) else { return }
        if code == activeCode {
            activate(codes[index == 0 ? 1 : index - 1])
        }
        codes.remove(at: index)
    }

    func remove(atOffsets offsets: IndexSet) {
        for code in offsets.map({ codes[$0] }) { remove(code) }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        codes.move(fromOffsets: source, toOffset: destination)
    }

    func toggle(_ code: String) {
        codes.contains(code) ? remove(code) : add(code)
    }

    /// Заменяет валюту в строке. Если новая уже есть в списке — строки меняются местами.
    func replace(_ old: String, with new: String) {
        guard old != new, let index = codes.firstIndex(of: old) else { return }
        if let existing = codes.firstIndex(of: new) {
            codes.swapAt(index, existing)
        } else {
            codes[index] = new
        }
        if activeCode == old { activeCode = new }
    }

    // MARK: - Обновление курсов

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            data = try await repository.refresh(previous: data)
            lastRefreshFailed = false
            rebuildCatalog()
        } catch {
            lastRefreshFailed = true
        }
        await loadWeek()
    }

    /// Прошлые дни лежат в кэше, поэтому повторный вызов почти бесплатный
    /// и заодно подхватывает новый день после полуночи.
    func loadWeek() async {
        let days = await history.days(range: .week)
        if days.map(\.date) != week.map(\.date) {
            week = days
        }
    }

    func sceneDidChange(isActive: Bool) {
        if isActive {
            if Date.now.timeIntervalSince(data.updatedAt) > 20 {
                Task { await refresh() }
            }
            restartAutoRefresh()
        } else {
            autoRefreshTask?.cancel()
            autoRefreshTask = nil
        }
    }

    func restartAutoRefresh() {
        autoRefreshTask?.cancel()
        let seconds = settings.refreshInterval.rawValue
        guard seconds > 0 else {
            autoRefreshTask = nil
            return
        }
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
            }
        }
    }

    // MARK: - Внутреннее

    private func rebuildCatalog() {
        let signature = "\(data.rates.count)|\(data.meta.crypto.count)|\(data.meta.fetchedAt.timeIntervalSince1970)"
        guard signature != catalogSignature else { return }
        catalogSignature = signature
        let list = CurrencyCatalog.build(codes: data.rates.keys, meta: data.meta)
        currencyByCode = Dictionary(uniqueKeysWithValues: list.map { ($0.code, $0) })
        currencies = list
    }

    private enum Keys {
        static let codes = "converter.codes"
        static let active = "converter.active"
        static let input = "converter.input"
    }
}
