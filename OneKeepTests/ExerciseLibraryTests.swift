import XCTest
@testable import OneKeep

final class ExerciseLibraryTests: XCTestCase {
    func testLibraryContainsOneHundredThirtyBuiltInExercises() {
        XCTAssertEqual(ExerciseLibraryCatalog.builtInItems.count, 130)
    }

    func testTraditionalFitnessCatalogHasCompleteExecutionMetadata() {
        let expected = ["baduanjin", "taiji-eight-methods-five-steps", "simplified-taiji-24", "wuqinxi", "yijinjing", "liuzijue"]
        let items = ExerciseLibraryCatalog.builtInItems.filter { expected.contains($0.id) }
        XCTAssertEqual(items.count, expected.count)
        XCTAssertTrue(items.allSatisfy { $0.category == .traditional })
        XCTAssertTrue(items.allSatisfy { $0.defaultTrackingMode == .countdown && ($0.defaultDurationSeconds ?? 0) > 0 })
        XCTAssertTrue(items.allSatisfy { !($0.breathingNotes ?? []).isEmpty })
        XCTAssertTrue(items.allSatisfy { !($0.contraindications ?? []).isEmpty })
        XCTAssertTrue(items.allSatisfy { !($0.videoAuthor ?? "").isEmpty && ($0.videoDurationSeconds ?? 0) > 0 })
    }

    func testEveryBuiltInHasCompleteLocalExecutionGuide() {
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !$0.summary.isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !$0.instructions.isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !$0.commonMistakes.isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.equipment ?? "").isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.primaryMuscles ?? []).isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.safetyNotes ?? []).isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.difficulty ?? "").isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.breathingNotes ?? []).isEmpty })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.contraindications ?? []).isEmpty })
    }

    func testMatchesCanonicalNameAndAlias() {
        XCTAssertEqual(ExerciseLibraryCatalog.match(name: "平板支撑")?.id, "plank")
        XCTAssertEqual(ExerciseLibraryCatalog.match(name: "无绳跳绳")?.id, "air-rope")
        XCTAssertEqual(ExerciseLibraryCatalog.match(name: "猫牛式")?.id, "cat-cow")
    }

    func testStructuredRecognitionSupportsIDEnglishAliasAndPrescriptionNoise() {
        XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: "平板支撑", libraryID: "plank").item?.id, "plank")
        XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: "鸟狗式", libraryID: "plank").item?.id, "bird-dog")
        XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: "Bird Dog").item?.id, "bird-dog")
        XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: "太极操").item?.id, "taiji-eight-methods-five-steps")
        XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: "平板支撑 3组").item?.id, "plank")
        XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: "db-goblet-squat").item?.id, "db-goblet-squat")
    }

    func testAIStructuredIndexContainsEveryCurrentLibraryItem() throws {
        let data = try XCTUnwrap(ExerciseLibraryCatalog.aiStructuredIndex.data(using: .utf8))
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(rows.count, ExerciseLibraryCatalog.allItems().count)
        XCTAssertTrue(rows.contains { $0["id"] as? String == "taiji-eight-methods-five-steps" })
        XCTAssertTrue(rows.allSatisfy { $0["id"] != nil && $0["name"] != nil && $0["trackingMode"] != nil })
    }

    func testEveryCanonicalNameRecognizesItsOwnLibraryID() {
        for item in ExerciseLibraryCatalog.builtInItems {
            XCTAssertEqual(ExerciseLibraryCatalog.recognize(name: item.name).item?.id, item.id, item.name)
        }
    }

    func testUncertainSimilarNameReturnsCandidateWithoutGuessing() {
        let result = ExerciseLibraryCatalog.recognize(name: "哑铃深蹲")
        XCTAssertNil(result.item)
        XCTAssertTrue(result.candidates.contains { $0.id == "db-goblet-squat" })
    }

    func testSharedAliasReturnsBothCandidatesInsteadOfGuessing() {
        let result = ExerciseLibraryCatalog.recognize(name: "后踢腿")
        XCTAssertNil(result.item)
        XCTAssertEqual(Set(result.candidates.map(\.id)), Set(["donkey-kick", "heel-kick"]))
    }

    func testAllRequestedPlanExercisesHaveLibraryEntries() {
        let names = [
            "靠墙站立", "猫式伸展", "高抬腿", "YTWL训练", "平板支撑", "空气跳绳",
            "扩胸运动", "鸟狗式", "登山跑", "坐姿收腹举腿", "侧支撑抬臀",
            "眼镜蛇式", "婴儿式", "靠墙手臂上举"
        ]
        XCTAssertTrue(names.allSatisfy { ExerciseLibraryCatalog.match(name: $0) != nil })
    }

    func testBuiltInVideoLinksAreEmbeddable() {
        let videos = ExerciseLibraryCatalog.builtInItems.compactMap(\.videoURL)
        XCTAssertEqual(videos.count, ExerciseLibraryCatalog.builtInItems.count)
        XCTAssertGreaterThanOrEqual(Set(videos).count, 115)
        XCTAssertTrue(videos.allSatisfy { VideoSource(urlString: $0.absoluteString) != nil })
        XCTAssertTrue(videos.allSatisfy { $0.host?.lowercased().hasSuffix("bilibili.com") == true })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { $0.videoReviewStatus == .reviewed })
        XCTAssertTrue(ExerciseLibraryCatalog.builtInItems.allSatisfy { !($0.alternateVideoURLs ?? []).isEmpty })
    }

    func testOlderOverrideWithoutVideoReceivesNewBuiltInVideo() throws {
        let suiteName = "ExerciseLibraryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var override = try XCTUnwrap(ExerciseLibraryCatalog.builtInItems.first)
        override.summary = "用户编辑过的说明"
        override.videoURL = nil
        try ExerciseLibraryPreferences.save([override], defaults: defaults)

        let merged = try XCTUnwrap(ExerciseLibraryCatalog.allItems(defaults: defaults).first { $0.id == override.id })
        XCTAssertEqual(merged.summary, "用户编辑过的说明")
        XCTAssertNotNil(merged.videoURL)
    }
}
