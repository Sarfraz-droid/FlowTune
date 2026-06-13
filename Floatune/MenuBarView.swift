import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ArtworkViewForMenu(url: model.snapshot.track.artworkURL)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.snapshot.track.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(model.snapshot.track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                Button { model.perform(.previous) } label: { Image(systemName: "backward.fill") }
                Button { model.perform(.playPause) } label: {
                    Image(systemName: model.snapshot.state == .playing ? "pause.fill" : "play.fill")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                Button { model.perform(.next) } label: { Image(systemName: "forward.fill") }
            }
            .buttonStyle(.glass)

            Divider()

            Button {
                model.settings.showFloatingPlayer.toggle()
            } label: {
                Label(
                    model.settings.showFloatingPlayer ? "Hide Floating Player" : "Show Floating Player",
                    systemImage: model.settings.showFloatingPlayer
                        ? "rectangle.slash"
                        : "macwindow.badge.plus"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.glass)
            Button {
                model.openSpotify()
            } label: {
                Label("Open Spotify", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Floatune", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(width: 300)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

private struct ArtworkViewForMenu: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Color.green.opacity(0.7)
                Image(systemName: "waveform").foregroundStyle(.white)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(.rect(cornerRadius: 12))
    }
}
