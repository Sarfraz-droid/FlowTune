import XCTest
@testable import Floatune

final class SpotifySnapshotParserTests: XCTestCase {
    func testParsesSpotifySnapshot() {
        let separator = SpotifySnapshotParser.separator
        let payload = [
            "playing",
            "Midnight City",
            "M83",
            "Hurry Up, We’re Dreaming",
            "https://example.com/art.jpg",
            "spotify:track:abc",
            "244500",
            "60.25",
            "75",
            "true",
            "false"
        ].joined(separator: separator)

        let snapshot = SpotifySnapshotParser.parse(payload)

        XCTAssertEqual(snapshot?.state, .playing)
        XCTAssertEqual(snapshot?.track.name, "Midnight City")
        XCTAssertEqual(snapshot?.track.duration, 244.5)
        XCTAssertEqual(snapshot?.position, 60.25)
        XCTAssertEqual(snapshot?.volume, 75)
        XCTAssertEqual(snapshot?.isShuffling, true)
        XCTAssertEqual(snapshot?.isRepeating, false)
    }

    func testConvertsSpotifyDurationFromMilliseconds() {
        let separator = SpotifySnapshotParser.separator
        let payload = [
            "playing", "Track", "Artist", "Album", "", "", "213333", "9", "50", "false", "false"
        ].joined(separator: separator)

        let snapshot = SpotifySnapshotParser.parse(payload)

        XCTAssertEqual(snapshot?.track.duration ?? -1, 213.333, accuracy: 0.001)
    }

    func testRejectsMalformedSnapshot() {
        XCTAssertNil(SpotifySnapshotParser.parse("playing"))
    }

    func testParsesSpotifyBooleansCaseInsensitively() {
        let separator = SpotifySnapshotParser.separator
        let payload = [
            "paused", "Track", "Artist", "Album", "", "", "180000", "12", "50", "TRUE", " Yes "
        ].joined(separator: separator)

        let snapshot = SpotifySnapshotParser.parse(payload)

        XCTAssertEqual(snapshot?.isShuffling, true)
        XCTAssertEqual(snapshot?.isRepeating, true)
    }
}
