import Foundation

enum PlayerAvailability: Equatable, Sendable {
    case ready
    case spotifyMissing
    case spotifyClosed
    case permissionDenied
    case unavailable(String)
}

enum PlaybackState: String, Equatable, Sendable {
    case playing
    case paused
    case stopped
}

struct TrackMetadata: Equatable, Sendable {
    var name: String
    var artist: String
    var album: String
    var artworkURL: URL?
    var spotifyURL: URL?
    var duration: TimeInterval

    static let empty = TrackMetadata(
        name: "Nothing playing",
        artist: "Open Spotify to get started",
        album: "",
        artworkURL: nil,
        spotifyURL: nil,
        duration: 0
    )
}

struct PlaybackSnapshot: Equatable, Sendable {
    var availability: PlayerAvailability
    var state: PlaybackState
    var track: TrackMetadata
    var position: TimeInterval
    var volume: Int
    var isShuffling: Bool
    var isRepeating: Bool
    var capturedAt: Date

    static let idle = PlaybackSnapshot(
        availability: .spotifyClosed,
        state: .stopped,
        track: .empty,
        position: 0,
        volume: 50,
        isShuffling: false,
        isRepeating: false,
        capturedAt: .now
    )

    func interpolatedPosition(at date: Date = .now) -> TimeInterval {
        guard state == .playing else { return position }
        return min(track.duration, max(0, position + date.timeIntervalSince(capturedAt)))
    }
}

enum PlaybackCommand: Equatable, Sendable {
    case playPause
    case next
    case previous
    case seek(TimeInterval)
    case volume(Int)
    case shuffle(Bool)
    case repeatMode(Bool)
}

protocol PlaybackService: Sendable {
    func fetchSnapshot() async -> PlaybackSnapshot
    func send(_ command: PlaybackCommand) async throws
    func openSpotify() async
}

