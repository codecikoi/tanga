import SwiftUI

@main
struct TangaApp: App {
    @State private var settings: AppSettings
    @State private var store: ConverterStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _store = State(initialValue: ConverterStore(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ConverterView()
                .environment(store)
                .environment(settings)
                .tint(Theme.accent)
                .onChange(of: settings.appearance, initial: true) { _, appearance in
                    applyInterfaceStyle(appearance)
                }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            store.sceneDidChange(isActive: phase == .active)
        }
    }

    /// Тема ставится на окно, а не через `preferredColorScheme`: тот при показе листа прибивает
    /// к нему свою тему и потом не обновляет — настройки оставались тёмными, пока их не закроешь.
    /// Стиль окна листы наследуют, поэтому смена темы сразу доходит до всех экранов.
    private func applyInterfaceStyle(_ appearance: AppAppearance) {
        let style: UIUserInterfaceStyle = switch appearance {
        case .dark: .dark
        case .light: .light
        case .system: .unspecified
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }
}
