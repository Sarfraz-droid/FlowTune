import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var shortcuts = GlobalShortcutManager.shared

    var body: some View {
        TabView {
            Form {
                Toggle("Keep player above other windows", isOn: $settings.alwaysOnTop)
                Toggle("Show floating player", isOn: $settings.showFloatingPlayer)
                Toggle("Start expanded", isOn: $settings.startsExpanded)
                Toggle(
                    "Launch Floatune at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .tabItem { Label("General", systemImage: "slider.horizontal.3") }

            Form {
                ForEach(ShortcutAction.allCases) { action in
                    HStack {
                        Text(action.title)
                        Spacer()
                        ShortcutRecorder(shortcut: shortcuts.shortcut(for: action)) {
                            shortcuts.set($0, for: action)
                        }
                        .frame(width: 130, height: 28)
                    }
                    if let error = shortcuts.errors[action] {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Text("Click a shortcut, then type a combination. Press Delete to clear it or Escape to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("Shortcuts", systemImage: "command") }
        }
        .frame(width: 520, height: 390)
    }
}

