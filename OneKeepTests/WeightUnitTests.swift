import XCTest
@testable import OneKeep

final class WeightUnitTests: XCTestCase {
    func testPoundsRoundTripUsesKilogramsAsCanonicalValue() throws {
        let pounds = WeightUnit.pounds.displayValue(fromKilograms: 100)
        XCTAssertEqual(pounds, 220.462_262_18, accuracy: 0.000_001)
        XCTAssertEqual(WeightUnit.pounds.kilograms(fromDisplayValue: pounds), 100, accuracy: 0.000_001)
    }

    func testOldPreferencesWithoutWeightUnitDefaultToKilograms() throws {
        let data = try XCTUnwrap("""
        {"timerNotifications":false,"hapticFeedback":true,"autoStartRest":false}
        """.data(using: .utf8))
        let preferences = try JSONDecoder().decode(WorkoutPreferences.self, from: data)
        XCTAssertEqual(preferences.weightUnit, .kilograms)
        XCTAssertFalse(preferences.timerNotifications)
    }

    func testSelectedUnitIsIncludedInPreferencesBackupPayload() throws {
        let source = WorkoutPreferences(weightUnit: .pounds)
        let restored = try JSONDecoder().decode(WorkoutPreferences.self, from: JSONEncoder().encode(source))
        XCTAssertEqual(restored, source)
    }
}
