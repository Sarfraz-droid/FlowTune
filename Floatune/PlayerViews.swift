import AppKit
import SwiftUI

struct FloatingPlayerView: View {
    @EnvironmentObject private var model: AppModel

    private var tint: Color {
        Color(
            red: model.artworkTint.red,
            green: model.artworkTint.green,
            blue: model.artworkTint.blue
        )
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            Group {
                if model.isExpanded {
                    expandedPlayer
                } else {
                    compactPlayer
                }
            }
            .padding(model.isExpanded ? 18 : 12)
            .glassEffect(.regular.tint(tint.opacity(0.22)).interactive(), in: .rect(cornerRadius: 32))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
        }
        .padding(8)
    }

    private var compactPlayer: some View {
        HStack(spacing: 10) {
            ArtworkView(url: model.snapshot.track.artworkURL, size: 60)
                .overlay(WindowDragHandle())
            trackText
                .frame(minWidth: 105, maxWidth: 140, alignment: .leading)
                .layoutPriority(1)
                .overlay(WindowDragHandle())
            Spacer(minLength: 2)
            PlaybackButton(systemName: "backward.fill", help: "Previous") {
                model.perform(.previous)
            }
            PlaybackButton(
                systemName: model.snapshot.state == .playing ? "pause.fill" : "play.fill",
                prominence: true,
                help: model.snapshot.state == .playing ? "Pause" : "Play"
            ) {
                model.perform(.playPause)
            }
            PlaybackButton(systemName: "forward.fill", help: "Next") {
                model.perform(.next)
            }
            VStack(spacing: 5) {
                Button {
                    model.toggleFloatingPlayer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                }
                .help("Close player")

                Button {
                    model.isExpanded = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .help("Expand")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    private var expandedPlayer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ArtworkView(url: model.snapshot.track.artworkURL, size: 82)
                    .overlay(WindowDragHandle())
                trackText
                    .overlay(WindowDragHandle())
                Spacer(minLength: 4)
                VStack(spacing: 9) {
                    Button {
                        model.toggleFloatingPlayer()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .help("Close player")

                    Button {
                        model.isExpanded = false
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .help("Collapse")

                    Button {
                        model.openSpotify()
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .help("Open Spotify")
                }
                .buttonStyle(.glass)
            }

            if case .ready = model.snapshot.availability {
                ProgressControls(snapshot: model.snapshot) { model.perform(.seek($0)) }
                transportControls
                volumeControls
            } else {
                AvailabilityView(availability: model.snapshot.availability) {
                    model.openSpotify()
                }
            }
        }
    }

    private var trackText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.snapshot.track.name)
                .font(.system(size: model.isExpanded ? 17 : 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text(model.snapshot.track.artist)
                .font(.system(size: model.isExpanded ? 13 : 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if model.isExpanded, model.snapshot.track.album.isEmpty == false {
                Text(model.snapshot.track.album)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var transportControls: some View {
        HStack(spacing: 18) {
            ToggleIconButton(
                systemName: "shuffle",
                active: model.snapshot.isShuffling,
                help: "Shuffle"
            ) {
                model.perform(.shuffle(!model.snapshot.isShuffling))
            }
            PlaybackButton(systemName: "backward.fill", help: "Previous") {
                model.perform(.previous)
            }
            PlaybackButton(
                systemName: model.snapshot.state == .playing ? "pause.fill" : "play.fill",
                prominence: true,
                size: 42,
                help: model.snapshot.state == .playing ? "Pause" : "Play"
            ) {
                model.perform(.playPause)
            }
            PlaybackButton(systemName: "forward.fill", help: "Next") {
                model.perform(.next)
            }
            ToggleIconButton(
                systemName: "repeat",
                active: model.snapshot.isRepeating,
                help: "Repeat"
            ) {
                model.perform(.repeatMode(!model.snapshot.isRepeating))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var volumeControls: some View {
        HStack(spacing: 10) {
            Image(systemName: model.snapshot.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(model.snapshot.volume) },
                    set: { model.setVolume(Int($0)) }
                ),
                in: 0...100,
                onEditingChanged: { editing in
                    if editing == false {
                        model.setVolume(model.snapshot.volume, commit: true)
                    }
                }
            )
            Text("\(model.snapshot.volume)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 25, alignment: .trailing)
        }
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

private final class DragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct ArtworkView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url, transaction: .init(animation: .easeInOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    LinearGradient(
                        colors: [.green.opacity(0.8), .teal.opacity(0.5), .black.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "waveform")
                        .font(.system(size: size * 0.3, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }
}

private struct ProgressControls: View {
    let snapshot: PlaybackSnapshot
    let seek: (TimeInterval) -> Void
    @State private var draggingPosition: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = draggingPosition ?? snapshot.interpolatedPosition(at: context.date)
            VStack(spacing: 3) {
                Slider(
                    value: Binding(
                        get: { position },
                        set: { draggingPosition = $0 }
                    ),
                    in: 0...max(1, snapshot.track.duration),
                    onEditingChanged: { editing in
                        if editing == false, let draggingPosition {
                            seek(draggingPosition)
                            self.draggingPosition = nil
                        }
                    }
                )
                HStack {
                    Text(position.timeLabel)
                    Spacer()
                    Text(snapshot.track.duration.timeLabel)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlaybackButton: View {
    let systemName: String
    var prominence = false
    var size: CGFloat = 34
    let help: String
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if prominence {
            button
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .help(help)
        } else {
            button
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(help)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: prominence ? 15 : 12, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
    }
}

private struct ToggleIconButton: View {
    let systemName: String
    let active: Bool
    let help: String
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if active {
            button
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(.green)
                .help("\(help) on")
        } else {
            button
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("\(help) off")
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(active ? Color.white : Color.primary)
                .frame(width: 28, height: 28)
        }
    }
}

private struct AvailabilityView: View {
    let availability: PlayerAvailability
    let openSpotify: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if canOpenSpotify {
                Button("Open Spotify", action: openSpotify)
                    .buttonStyle(.glassProminent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch availability {
        case .spotifyMissing: "Spotify isn’t installed"
        case .spotifyClosed: "Spotify is closed"
        case .permissionDenied: "Automation access is off"
        case .unavailable: "Can’t reach Spotify"
        case .ready: ""
        }
    }

    private var detail: String {
        switch availability {
        case .spotifyMissing: "Install Spotify for macOS to use Floatune."
        case .spotifyClosed: "Launch Spotify and start something you love."
        case .permissionDenied: "Enable Floatune in System Settings › Privacy & Security › Automation."
        case .unavailable(let message): message
        case .ready: ""
        }
    }

    private var icon: String {
        switch availability {
        case .spotifyMissing: "arrow.down.app"
        case .spotifyClosed: "moon.zzz"
        case .permissionDenied: "lock.trianglebadge.exclamationmark"
        case .unavailable: "exclamationmark.triangle"
        case .ready: "checkmark"
        }
    }

    private var canOpenSpotify: Bool {
        if case .spotifyClosed = availability { return true }
        return false
    }
}

private extension TimeInterval {
    var timeLabel: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self)
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
