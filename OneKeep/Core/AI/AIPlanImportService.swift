import Foundation

struct AIPlanImportService {
    enum ImportError: LocalizedError {
        case invalidJSON
        case invalidDate(String)
        case invalidScheduleKind(String)
        case invalidBlockKind(String)
        case invalidTrackingMode(String)
        case invalidWeekday(Int)

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "AI 没有返回有效的计划 JSON"
            case .invalidDate(let value): return "无法识别日期：\(value)"
            case .invalidScheduleKind(let value): return "无法识别日程类型：\(value)"
            case .invalidBlockKind(let value): return "无法识别训练阶段：\(value)"
            case .invalidTrackingMode(let value): return "无法识别动作记录方式：\(value)"
            case .invalidWeekday(let value): return "星期值必须在 1 到 7 之间：\(value)"
            }
        }
    }

    private let client: OpenAICompatibleClient

    init(client: OpenAICompatibleClient = OpenAICompatibleClient()) {
        self.client = client
    }

    func importPlan(
        sourceText: String,
        provider: AIProviderConfiguration,
        apiKey: String
    ) async throws -> TrainingPlan {
        let content = try await client.complete(
            configuration: .init(
                baseURL: provider.baseURL,
                model: provider.model,
                apiKey: apiKey,
                usesJSONMode: provider.usesJSONMode
            ),
            developerMessage: Self.developerPrompt,
            userMessage: "请把下面内容整理成计划 JSON。不要改变用户的训练决定，只整理结构。\n\n\(sourceText)"
        )
        return try Self.parse(content)
    }

    static func parse(_ content: String) throws -> TrainingPlan {
        guard let data = extractJSONData(from: content) else {
            throw ImportError.invalidJSON
        }
        let draft = try JSONDecoder().decode(AIPlanDraft.self, from: data)
        return try draft.makePlan()
    }

    private static func extractJSONData(from content: String) -> Data? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: direct)) != nil {
            return direct
        }

        guard let first = trimmed.firstIndex(of: "{"),
              let last = trimmed.lastIndex(of: "}"),
              first <= last else {
            return nil
        }
        let candidate = String(trimmed[first...last])
        guard let data = candidate.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }
        return data
    }

    private static let developerPrompt = """
    你是训练计划结构化助手。用户已经自行决定计划，你只能整理，不得修改、增删或评价训练内容。
    只返回一个 JSON 对象，不要返回 Markdown。字段必须符合以下结构：
    {
      "title": "计划名称",
      "startDate": "yyyy-MM-dd",
      "endDate": "yyyy-MM-dd 或 null",
      "days": [{
        "title": "训练日名称",
        "scheduleKind": "specificDate | weekly | biweekly",
        "anchorDate": "yyyy-MM-dd",
        "weekdays": [1到7，1代表周日，2代表周一],
        "blocks": [{
          "title": "阶段名称",
          "kind": "warmup | standard | interval | circuit | cooldown",
          "rounds": 1,
          "restBetweenExercisesSeconds": 0,
          "restBetweenRoundsSeconds": 0,
          "exercises": [{
            "name": "动作名",
            "sets": 1,
            "repetitions": "次数或区间，也可为null",
            "weightKilograms": null,
            "durationSeconds": null,
            "restSeconds": 0,
            "notes": null,
            "videoURL": null,
            "trackingMode": "repetitions | countdown | stopwatch"
          }]
        }]
      }]
    }
    指定日期时 weekdays 为空数组。所有秒数使用整数。没有重量时必须为 null。
    """
}

private struct AIPlanDraft: Decodable {
    struct Day: Decodable {
        struct Block: Decodable {
            struct Exercise: Decodable {
                let name: String
                let sets: Int
                let repetitions: String?
                let weightKilograms: Double?
                let durationSeconds: Int?
                let restSeconds: Int
                let notes: String?
                let videoURL: String?
                let trackingMode: String
            }

            let title: String
            let kind: String
            let rounds: Int
            let restBetweenExercisesSeconds: Int
            let restBetweenRoundsSeconds: Int
            let exercises: [Exercise]
        }

        let title: String
        let scheduleKind: String
        let anchorDate: String
        let weekdays: [Int]
        let blocks: [Block]
    }

    let title: String
    let startDate: String
    let endDate: String?
    let days: [Day]

    func makePlan() throws -> TrainingPlan {
        let parser = ISODateOnlyParser()
        let start = try parser.date(startDate)
        let end = try endDate.map(parser.date)

        let mappedDays = try days.map { day in
            guard let kind = ScheduleRule.Kind(rawValue: day.scheduleKind) else {
                throw AIPlanImportService.ImportError.invalidScheduleKind(day.scheduleKind)
            }
            for weekday in day.weekdays where !(1...7).contains(weekday) {
                throw AIPlanImportService.ImportError.invalidWeekday(weekday)
            }

            let blocks = try day.blocks.map { block in
                guard let blockKind = WorkoutBlock.Kind(rawValue: block.kind) else {
                    throw AIPlanImportService.ImportError.invalidBlockKind(block.kind)
                }
                let exercises = try block.exercises.map { exercise in
                    guard let trackingMode = PlannedExercise.TrackingMode(rawValue: exercise.trackingMode) else {
                        throw AIPlanImportService.ImportError.invalidTrackingMode(exercise.trackingMode)
                    }
                    return PlannedExercise(
                        name: exercise.name,
                        sets: exercise.sets,
                        repetitions: exercise.repetitions,
                        plannedWeightKilograms: exercise.weightKilograms,
                        durationSeconds: exercise.durationSeconds,
                        restSeconds: exercise.restSeconds,
                        notes: exercise.notes,
                        videoURL: exercise.videoURL.flatMap(URL.init(string:)),
                        trackingMode: trackingMode
                    )
                }
                return WorkoutBlock(
                    title: block.title,
                    kind: blockKind,
                    rounds: block.rounds,
                    restBetweenExercisesSeconds: block.restBetweenExercisesSeconds,
                    restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                    exercises: exercises
                )
            }

            return TrainingDay(
                title: day.title,
                recurrence: ScheduleRule(
                    kind: kind,
                    anchorDate: try parser.date(day.anchorDate),
                    weekdays: Set(day.weekdays),
                    endDate: end
                ),
                blocks: blocks
            )
        }

        let plan = TrainingPlan(title: title, startDate: start, endDate: end, days: mappedDays)
        try PlanDocumentCodec.validate(plans: [plan])
        return plan
    }
}

private struct ISODateOnlyParser {
    private let formatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        self.formatter = formatter
    }

    func date(_ value: String) throws -> Date {
        guard let date = formatter.date(from: value) else {
            throw AIPlanImportService.ImportError.invalidDate(value)
        }
        return date
    }
}
