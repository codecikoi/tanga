import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ConverterStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var cacheCleared = false

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
                            Text("Sarrof").font(.title3.weight(.semibold))
                            Text("«Меняла» по-узбекски. Валюты мира, криптовалюты и металлы.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Курсы") {
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
                    source("Coinbase", "Живые курсы фиата и крипты, раз в минуту", "https://www.coinbase.com")
                    source("Currency API", "340 валют и металлы, дневная история для графиков",
                           "https://github.com/fawazahmed0/exchange-api")
                    source("flagcdn.com", "Флаги стран", "https://flagcdn.com")
                    source("CoinCap", "Иконки криптовалют", "https://coincap.io")
                } header: {
                    Text("Источники данных")
                } footer: {
                    Text("Все источники бесплатные и без ключей. Курсы справочные — в банке и обменнике они отличаются.")
                }

                Section {
                    Button(cacheCleared ? "Кэш очищен" : "Очистить кэш графиков и иконок", role: .destructive) {
                        store.history.clearCache()
                        ImageLoader.shared.clearCache()
                        cacheCleared = true
                    }
                    .disabled(cacheCleared)
                }

                Section {
                    LabeledContent("Версия", value: version)
                }
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

    private func source(_ title: String, _ detail: String, _ link: String) -> some View {
        Link(destination: URL(string: link)!) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
