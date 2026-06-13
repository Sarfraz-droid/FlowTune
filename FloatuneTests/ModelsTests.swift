import XCTest
@testable import Floatune

final class ModelsTests: XCTestCase {
    func testPlayingPositionInterpolatesAndClampsToDuration() {
        let captured = Date(timeIntervalSince1970: 100)
        let snapshot = PlaybackSnapshot(
            availability: .ready,
            state: .playing,
            track: TrackMetadata(
                name: "Track",
                artist: "Artist",
                album: "Album",
                artworkURL: nil,
                spotifyURL: nil,
                duration: 120
            ),
            position: 118,
            volume: 50,
            isShuffling: false,
            isRepeating: false,
            capturedAt: captured
        )

        XCTAssertEqual(snapshot.interpolatedPosition(at: captured.addingTimeInterval(1)), 119)
        XCTAssertEqual(snapshot.interpolatedPosition(at: captured.addingTimeInterval(10)), 120)
    }

    func testPausedPositionDoesNotInterpolate() {
        var snapshot = PlaybackSnapshot.idle
        snapshot.state = .paused
        snapshot.position = 42
        snapshot.capturedAt = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(snapshot.interpolatedPosition(at: Date(timeIntervalSince1970: 200)), 42)
    }
}

