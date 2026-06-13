import AppKit
import Foundation

struct SpotifySnapshotParser {
    static let separator = "\u{1F}"

    static func parse(_ value: String, capturedAt: Date = .now) -> PlaybackSnapshot? {
        let fields = value.components(separatedBy: separator)
        guard fields.count == 11 else { return nil }

        let state = PlaybackState(rawValue: fields[0]) ?? .stopped
        // Spotify's current macOS client exposes track duration in
        // milliseconds even though its scripting dictionary says seconds.
        let duration = (TimeInterval(fields[6]) ?? 0) / 1_000
        let track = TrackMetadata(
            name: fields[1].isEmpty ? "Nothing playing" : fields[1],
            artist: fields[2].isEmpty ? "Spotify" : fields[2],
            album: fields[3],
            artworkURL: URL(string: fields[4]),
            spotifyURL: URL(string: fields[5]),
            duration: duration
        )

        return PlaybackSnapshot(
            availability: .ready,
            state: state,
            track: track,
            position: TimeInterval(fields[7]) ?? 0,
            volume: Int(fields[8]) ?? 50,
            isShuffling: parseBoolean(fields[9]),
            isRepeating: parseBoolean(fields[10]),
            capturedAt: capturedAt
        )
    }

    private static func parseBoolean(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1":
            true
        default:
            false
        }
    }
}

actor SpotifyPlaybackService: PlaybackService {
    private let bundleIdentifier = "com.spotify.client"

    func fetchSnapshot() async -> PlaybackSnapshot {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
            var snapshot = PlaybackSnapshot.idle
            snapshot.availability = .spotifyMissing
            return snapshot
        }

        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty == false else {
            return .idle
        }

        let script = """
        tell application id "com.spotify.client"
            set unitSeparator to ASCII character 31
            set playbackState to (player state as string)
            if playbackState is "stopped" then
                return playbackState & unitSeparator & "" & unitSeparator & "" & unitSeparator & "" & unitSeparator & "" & unitSeparator & "" & unitSeparator & "0" & unitSeparator & "0" & unitSeparator & (sound volume as string) & unitSeparator & (shuffling as string) & unitSeparator & (repeating as string)
            end if
            set currentItem to current track
            return playbackState & unitSeparator & (name of currentItem) & unitSeparator & (artist of currentItem) & unitSeparator & (album of currentItem) & unitSeparator & (artwork url of currentItem) & unitSeparator & (spotify url of currentItem) & unitSeparator & (duration of currentItem as string) & unitSeparator & (player position as string) & unitSeparator & (sound volume as string) & unitSeparator & (shuffling as string) & unitSeparator & (repeating as string)
        end tell
        """

        do {
            let output = try run(script)
            return SpotifySnapshotParser.parse(output) ?? unavailable("Spotify returned an unexpected response.")
        } catch let error as AppleScriptFailure {
            switch error.number {
            case -1743:
                var snapshot = PlaybackSnapshot.idle
                snapshot.availability = .permissionDenied
                return snapshot
            case -600:
                return .idle
            default:
                return unavailable(error.message)
            }
        } catch {
            return unavailable(error.localizedDescription)
        }
    }

    func send(_ command: PlaybackCommand) async throws {
        let body: String
        switch command {
        case .playPause:
            body = "playpause"
        case .next:
            body = "next track"
        case .previous:
            body = "previous track"
        case .seek(let position):
            body = "set player position to \(max(0, position))"
        case .volume(let volume):
            body = "set sound volume to \(min(100, max(0, volume)))"
        case .shuffle(let enabled):
            body = "set shuffling to \(enabled)"
        case .repeatMode(let enabled):
            body = "set repeating to \(enabled)"
        }
        _ = try run("tell application id \"com.spotify.client\" to \(body)")
    }

    func openSpotify() async {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private func unavailable(_ message: String) -> PlaybackSnapshot {
        var snapshot = PlaybackSnapshot.idle
        snapshot.availability = .unavailable(message)
        return snapshot
    }

    private func run(_ source: String) throws -> String {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptFailure(number: -1, message: "Could not create AppleScript.")
        }
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw AppleScriptFailure(
                number: errorInfo[NSAppleScript.errorNumber] as? Int ?? -1,
                message: errorInfo[NSAppleScript.errorMessage] as? String ?? "Spotify automation failed."
            )
        }
        return result.stringValue ?? ""
    }
}

private struct AppleScriptFailure: Error {
    let number: Int
    let message: String
}
