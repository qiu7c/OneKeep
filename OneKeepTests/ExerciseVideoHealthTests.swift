import XCTest
@testable import OneKeep

final class ExerciseVideoHealthTests: XCTestCase {
    func testUnavailablePrimaryFallsBackToAlternate() throws {
        let suiteName = "ExerciseVideoHealthTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let primary = try XCTUnwrap(URL(string: "https://example.com/primary.mp4"))
        let alternate = try XCTUnwrap(URL(string: "https://example.com/alternate.mp4"))
        var item = try XCTUnwrap(ExerciseLibraryCatalog.builtInItems.first)
        item.videoURL = primary
        item.alternateVideoURLs = [alternate]
        ExerciseVideoHealthStore.save(
            ExerciseVideoHealthRecord(
                url: primary, status: .unavailable, checkedAt: .now, title: nil,
                author: nil, thumbnailURL: nil, message: "gone"
            ),
            defaults: defaults
        )
        XCTAssertEqual(ExerciseMediaResolver.playableURL(for: item, defaults: defaults), alternate)
    }

    func testOldExerciseLibraryJSONDecodesWithoutMediaMetadata() throws {
        let item = try XCTUnwrap(ExerciseLibraryCatalog.builtInItems.first)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        object.removeValue(forKey: "alternateVideoURLs")
        object.removeValue(forKey: "videoReviewStatus")
        object.removeValue(forKey: "videoReviewedAt")
        object.removeValue(forKey: "difficulty")
        object.removeValue(forKey: "breathingNotes")
        object.removeValue(forKey: "contraindications")
        object.removeValue(forKey: "videoAuthor")
        object.removeValue(forKey: "videoDurationSeconds")
        let restored = try JSONDecoder().decode(ExerciseLibraryItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.alternateVideoURLs)
        XCTAssertNil(restored.videoReviewStatus)
        XCTAssertNil(restored.breathingNotes)
        XCTAssertNil(restored.contraindications)
    }
}
