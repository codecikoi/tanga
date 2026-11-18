import SwiftUI

enum DisplayPrecision: String, CaseIterable, Identifiable {
    case auto, zero, two, four

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Авто"
        case .zero: "0"
        case .two: "0,00"
        case .four: "0,0000"
        }
    }

    var fixedDigits: Int? {
        switch self {
        case .auto: nil
        case .zero: 0
        case .two: 2
        case .four: 4
        }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fast = 30
    case minute = 60
    case fiveMinutes = 300
    case manual = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fast: "Каждые 30 сек"
        case .minute: "Каждую минуту"
        case .fiveMinutes: "Каждые 5 мин"
        case .manual: "Только вручную"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark, light, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Тёмная"
        case .light: "Светлая"
        case .system: "Как в системе"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

@Observable
final class AppSettings {
    var precision: DisplayPrecision {
        didSet { defaults.set(precision.rawValue, forKey: Keys.precision) }
    }
    var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Keys.refresh) }
    }
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Keys.haptics) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        precision = DisplayPrecision(rawValue: defaults.string(forKey: Keys.precision) ?? "") ?? .auto
        refreshInterval = (defaults.object(forKey: Keys.refresh) as? Int).flatMap(RefreshInterval.init(rawValue:)) ?? .minute
        appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .dark
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    }

    private enum Keys {
        static let precision = "settings.precision"
        static let refresh = "settings.refreshInterval"
        static let appearance = "settings.appearance"
        static let haptics = "settings.haptics"
    }
}
