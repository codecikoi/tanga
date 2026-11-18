import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ConverterStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var choosingMain = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(.logo)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("TANGA").font(.title3.weight(.semibold))
                            Text("«Монета» по-узбекски. Валюты мира, криптовалюты и металлы.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button { choosingMain = true } label: {
                        HStack(spacing: 10) {
                            Text("Основная валюта")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            CurrencyBadge(code: settings.mainCurrency, currency: store.currency(settings.mainCurrency),
                                          width: 27, height: 19)
                            Text(settings.mainCurrency)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("Мини-графики и проценты в строках показывают, сколько валюта стоит в основной. С ней же открывается график курса.")
                }

                Section {
                    Picker("Автообновление", selection: $settings.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Валют в базе", value: "\(store.currencies.count)")
                    LabeledContent("Обновлено", value: updatedText)
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        HStack {
                            Text("Обновить сейчас")
                            Spacer()
                            if store.isRefreshing { ProgressView() }
                        }
                    }
                } header: {
                    Text("Курсы")
                } footer: {
                    Text("Курсы справочные — в банке и обменнике они отличаются.")
                }

                Section("Отображение") {
                    Picker("Знаков после запятой", selection: $settings.precision) {
                        ForEach(DisplayPrecision.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Тема", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Отклик клавиш", isOn: $settings.haptics)
                }

                Section {
                    LabeledContent("Версия", value: version)
                }
            }
            .sheet(isPresented: $choosingMain) {
                CurrencyPickerView(mode: .choose(title: "Основная валюта", selected: settings.mainCurrency) {
                    settings.mainCurrency = $0
                })
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private var updatedText: String {
        let date = store.data.updatedAt
        guard date != .distantPast else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
