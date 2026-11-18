import SwiftUI

@main
struct SarrofApp: App {
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
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            store.sceneDidChange(isActive: phase == .active)
        }
    }
}
