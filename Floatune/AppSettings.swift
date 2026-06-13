import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let alwaysOnTop = "alwaysOnTop"
        static let startsExpanded = "startsExpanded"
        static let showFloatingPlayer = "showFloatingPlayer"
    }

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Key.alwaysOnTop) }
    }

    @Published var startsExpanded: Bool {
        didSet { defaults.set(startsExpanded, forKey: Key.startsExpanded) }
    }

    @Published var showFloatingPlayer: Bool {
        didSet { defaults.set(showFloatingPlayer, forKey: Key.showFloatingPlayer) }
    }

    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.alwaysOnTop: true,
            Key.startsExpanded: false,
            Key.showFloatingPlayer: true
        ])
        alwaysOnTop = defaults.bool(forKey: Key.alwaysOnTop)
        startsExpanded = defaults.bool(forKey: Key.startsExpanded)
        showFloatingPlayer = defaults.bool(forKey: Key.showFloatingPlayer)
        refreshLaunchAtLogin()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

