import SwiftUI
import Foundation

final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bool(_ key: SettingsKey, defaultValue: Bool = false) -> Bool {
        if defaults.object(forKey: key.rawValue) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key.rawValue)
    }

    func string(_ key: SettingsKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func set(_ value: Bool, for key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    func set(_ value: String, for key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }
}

enum SettingsKey: String {
    case useComputationalPhotography
    case defaultFormat
    case defaultLens
    case defaultFlashMode
    case defaultAspectRatio
    case showGrid
    case embedLocation
    case hasShownOnboarding
    case panelExpandedAtLaunch
    case hapticFeedbackEnabled
    case objectDetectionEnabled
}

@MainActor
@Observable
final class Settings {

    private let store: SettingsStore

    var useComputationalPhotography: Bool {
        didSet { store.set(useComputationalPhotography, for: .useComputationalPhotography) }
    }

    var defaultFormat: PhotoFormat {
        didSet { store.set(defaultFormat.rawValue, for: .defaultFormat) }
    }

    var defaultLens: Lens {
        didSet { store.set(defaultLens.rawValue, for: .defaultLens) }
    }

    var defaultFlashMode: FlashMode {
        didSet { store.set(defaultFlashMode.rawValue, for: .defaultFlashMode) }
    }

    var defaultAspectRatio: AspectRatio {
        didSet { store.set(defaultAspectRatio.rawValue, for: .defaultAspectRatio) }
    }

    var showGrid: Bool {
        didSet { store.set(showGrid, for: .showGrid) }
    }

    var embedLocation: Bool {
        didSet { store.set(embedLocation, for: .embedLocation) }
    }

    var hasShownOnboarding: Bool {
        didSet { store.set(hasShownOnboarding, for: .hasShownOnboarding) }
    }

    var panelExpandedAtLaunch: Bool {
        didSet { store.set(panelExpandedAtLaunch, for: .panelExpandedAtLaunch) }
    }

    var hapticFeedbackEnabled: Bool {
        didSet { store.set(hapticFeedbackEnabled, for: .hapticFeedbackEnabled) }
    }

    var objectDetectionEnabled: Bool {
        didSet { store.set(objectDetectionEnabled, for: .objectDetectionEnabled) }
    }

    init(store: SettingsStore = SettingsStore()) {
        self.store = store

        self.useComputationalPhotography = store.bool(.useComputationalPhotography)

        if let raw = store.string(.defaultFormat),
           let format = PhotoFormat(rawValue: raw) {
            self.defaultFormat = format
        } else {
            self.defaultFormat = .heif
        }

        if let raw = store.string(.defaultLens),
           let lens = Lens(rawValue: raw) {
            self.defaultLens = lens
        } else {
            self.defaultLens = .wide
        }

        if let raw = store.string(.defaultFlashMode),
           let mode = FlashMode(rawValue: raw) {
            self.defaultFlashMode = mode
        } else {
            self.defaultFlashMode = .off
        }

        if let raw = store.string(.defaultAspectRatio),
           let ratio = AspectRatio(rawValue: raw) {
            self.defaultAspectRatio = ratio
        } else {
            self.defaultAspectRatio = .fullScreen
        }

        self.showGrid = store.bool(.showGrid)
        self.embedLocation = store.bool(.embedLocation)
        self.hasShownOnboarding = store.bool(.hasShownOnboarding)
        self.panelExpandedAtLaunch = store.bool(.panelExpandedAtLaunch)
        self.hapticFeedbackEnabled = store.bool(.hapticFeedbackEnabled, defaultValue: true)
        self.objectDetectionEnabled = store.bool(.objectDetectionEnabled)
    }

    func resetToDefaults() {
        useComputationalPhotography = false
        defaultFormat = .heif
        defaultLens = .wide
        defaultFlashMode = .off
        defaultAspectRatio = .fullScreen
        showGrid = false
        embedLocation = false
        panelExpandedAtLaunch = false
        hapticFeedbackEnabled = true
        objectDetectionEnabled = false
    }
}
