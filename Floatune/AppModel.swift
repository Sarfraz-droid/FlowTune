import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var snapshot: PlaybackSnapshot = .idle
    @Published var isExpanded = AppSettings.shared.startsExpanded
    @Published var artworkTint: ColorComponents = .spotify

    let settings = AppSettings.shared
    let shortcuts = GlobalShortcutManager.shared
    private let service: any PlaybackService
    private var pollTask: Task<Void, Never>?
    private var volumeSendTask: Task<Void, Never>?
    private var pendingVolume: Int?
    private var volumeOverrideUntil = Date.distantPast

    init(service: any PlaybackService = SpotifyPlaybackService()) {
        self.service = service
        configureShortcuts()
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while Task.isCancelled == false {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func refresh() async {
        var newSnapshot = await service.fetchSnapshot()
        if Date.now < volumeOverrideUntil {
            newSnapshot.volume = snapshot.volume
        }
        let artworkChanged = newSnapshot.track.artworkURL != snapshot.track.artworkURL
        snapshot = newSnapshot
        if artworkChanged {
            await updateArtworkTint(from: newSnapshot.track.artworkURL)
        }
    }

    func perform(_ command: PlaybackCommand) {
        if case .volume(let volume) = command {
            setVolume(volume)
            return
        }

        applyOptimisticState(for: command)
        Task {
            do {
                try await service.send(command)
                try? await Task.sleep(for: .milliseconds(300))
                await refresh()
                try? await Task.sleep(for: .milliseconds(500))
                await refresh()
            } catch {
                var failed = snapshot
                failed.availability = .unavailable(error.localizedDescription)
                snapshot = failed
            }
        }
    }

    func setVolume(_ volume: Int, commit: Bool = false) {
        let normalized = min(100, max(0, volume))
        snapshot.volume = normalized
        pendingVolume = normalized
        volumeOverrideUntil = Date.now.addingTimeInterval(commit ? 0.6 : 1.2)

        if commit {
            volumeSendTask?.cancel()
            volumeSendTask = nil
        }
        startVolumeSenderIfNeeded()
    }

    func openSpotify() {
        Task { await service.openSpotify() }
    }

    func toggleFloatingPlayer() {
        FloatingPanelController.shared.toggle()
    }

    private func configureShortcuts() {
        shortcuts.onAction = { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                switch action {
                case .toggleWindow: self.toggleFloatingPlayer()
                case .playPause: self.perform(.playPause)
                case .previous: self.perform(.previous)
                case .next: self.perform(.next)
                case .shuffle: self.perform(.shuffle(!self.snapshot.isShuffling))
                case .repeatMode: self.perform(.repeatMode(!self.snapshot.isRepeating))
                }
            }
        }
        shortcuts.registerAll()
    }

    private func applyOptimisticState(for command: PlaybackCommand) {
        switch command {
        case .shuffle(let enabled):
            snapshot.isShuffling = enabled
        case .repeatMode(let enabled):
            snapshot.isRepeating = enabled
        default:
            break
        }
    }

    private func startVolumeSenderIfNeeded() {
        guard volumeSendTask == nil else { return }

        volumeSendTask = Task { [weak self] in
            guard let self else { return }
            while Task.isCancelled == false {
                guard let volume = self.pendingVolume else { break }
                self.pendingVolume = nil
                do {
                    try await self.service.send(.volume(volume))
                } catch {
                    var failed = self.snapshot
                    failed.availability = .unavailable(error.localizedDescription)
                    self.snapshot = failed
                    break
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
            self.volumeSendTask = nil
            if self.pendingVolume != nil {
                self.startVolumeSenderIfNeeded()
            }
        }
    }

    private func updateArtworkTint(from url: URL?) async {
        guard let url else {
            artworkTint = .spotify
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data), let color = image.averageColor else { return }
            artworkTint = ColorComponents(color: color)
        } catch {
            artworkTint = .spotify
        }
    }
}

struct ColorComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    static let spotify = ColorComponents(red: 0.11, green: 0.72, blue: 0.33)

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(color: NSColor) {
        let converted = color.usingColorSpace(.sRGB) ?? .systemGreen
        red = Double(converted.redComponent)
        green = Double(converted.greenComponent)
        blue = Double(converted.blueComponent)
    }
}

private extension NSImage {
    var averageColor: NSColor? {
        guard
            let data = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: data)
        else { return nil }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count: CGFloat = 0
        let step = max(1, min(width, height) / 24)

        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return NSColor(red: red / count, green: green / count, blue: blue / count, alpha: 1)
    }
}
