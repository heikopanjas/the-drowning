import DrownedModel
import Foundation
import Testing

struct ModelTests {
    @Test(
        "Coordinate parser accepts valid source fields",
        arguments: [
            ("32.22804, -112.590416", 32.22804, -112.590416),
            (" 36.0, 17.5 ", 36.0, 17.5),
        ]
    )
    func validCoordinateParsing(field: String, latitude: Double, longitude: Double) throws {
        let coordinate = try #require(Coordinate(field: field))
        #expect(coordinate.latitude == latitude)
        #expect(coordinate.longitude == longitude)
    }

    @Test(
        "Coordinate parser rejects empty malformed or out of range fields",
        arguments: ["", "32.0", "north, west", "91, 0", "0, 181"]
    )
    func invalidCoordinateParsing(field: String) {
        #expect(Coordinate(field: field) == nil)
    }

    @Test("Region mapping preserves known strings and falls back to unknown")
    func regionMapping() {
        #expect(Region(source: "Mediterranean") == .mediterranean)
        #expect(Region(source: "South-eastern Asia") == .southEasternAsia)
        #expect(Region(source: "Sub-Saharan Africa") == .unknown)
    }
}
