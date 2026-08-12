import Foundation

struct AIPlanImportService {
    enum ImportError: LocalizedError {
        case invalidJSON
        case invalidDate(String)
        case invalidScheduleKind(String)
        case invalidBlockKind(String)
        case invalidTrackingMode(String)
        case invalidWeekday(Int)
        case emptyResponseAfterRetries

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "AI 没有返回有效的计划 JSON"
            case .invalidDate(let value): return "无法识别日期：\(value)"
            case .invalidScheduleKind(let value): return "无法识别日程类型：\(value)"
            case .invalidBlockKind(let value): return "无法识别训练阶段：\(value)"
            case .invalidTrackingMode(let value): return "无法识别动作记录方式：\(value)"
            case .invalidWeekday(let value): return "星期值必须在 1 到 7 之间：\(value)"
            case .emptyResponseAfterRetries: return "AI 服务连续返回空内容，OneKeep 已自动切换请求模式重试。请确认当前模型支持聊天补全后再试"
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
        try await importPlan(
            conversation: [AIChatMessage(role: .user, content: sourceText)],
            provider: provider,
            apiKey: apiKey
        )
    }

    func importPlan(
        conversation: [AIChatMessage],
        provider: AIProviderConfiguration,
        apiKey: String
    ) async throws -> TrainingPlan {
        let transcript = conversation.suffix(30).map { message in
            "\(message.role == .user ? "用户" : "助手")：\(message.content)"
        }.joined(separator: "\n\n")
        let messages: [OpenAICompatibleClient.Message] = [
            .init(role: "system", content: Self.recommendedPrompt),
            .init(role: "system", content: AIRequestContext.currentDateMessage()),
            .init(role: "user", content: "根据以下完整对话，把用户原始计划和用户明确确认的修改整理成最终计划 JSON。助手尚未被用户确认的建议不得写入。\n\n\(transcript)")
        ]
        let configuration = OpenAICompatibleClient.Configuration(
            baseURL: provider.baseURL,
            model: provider.model,
            apiKey: apiKey,
            usesJSONMode: provider.usesJSONMode
        )
        let content = try await requestPlanContent(
            configuration: configuration,
            messages: messages,
            preferredJSONMode: provider.usesJSONMode
        )
        do {
            return try linkToExerciseLibrary(Self.parse(content))
        } catch {
            let repairMessages = messages + [
                .init(role: "assistant", content: content),
                .init(role: "user", content: "上一个 JSON 无法被应用解析。请只修复格式和缺失字段，不改变计划内容；严格返回一个符合系统结构的 JSON 对象。")
            ]
            let repaired = try await requestPlanContent(
                configuration: configuration,
                messages: repairMessages,
                preferredJSONMode: provider.usesJSONMode
            )
            return try linkToExerciseLibrary(Self.parse(repaired))
        }
    }

    private func requestPlanContent(
        configuration: OpenAICompatibleClient.Configuration,
        messages: [OpenAICompatibleClient.Message],
        preferredJSONMode: Bool
    ) async throws -> String {
        let modes = preferredJSONMode ? [true, false, false] : [false, true, false]
        var lastError: Error = OpenAICompatibleClient.ClientError.missingContent

        for (attempt, jsonMode) in modes.enumerated() {
            var requestMessages = messages
            if attempt > 0 {
                requestMessages.append(.init(
                    role: "user",
                    content: "上一次请求没有返回可用内容。请立即输出完整、单行、紧凑的计划 JSON；不要分析，不要解释，不要使用 Markdown。"
                ))
            }
            do {
                return try await client.completeContinuing(
                    configuration: configuration,
                    messages: requestMessages,
                    forceJSONMode: jsonMode,
                    acceptReasoningContentFallback: true,
                    timeout: 120
                ).content
            } catch {
                lastError = error
                guard Self.shouldRetryGeneration(error) else { throw error }
            }
        }

        if let clientError = lastError as? OpenAICompatibleClient.ClientError,
           clientError == .missingContent {
            throw ImportError.emptyResponseAfterRetries
        }
        throw lastError
    }

    private static func shouldRetryGeneration(_ error: Error) -> Bool {
        guard let clientError = error as? OpenAICompatibleClient.ClientError else { return false }
        switch clientError {
        case .missingContent, .truncated, .invalidResponse:
            return true
        case .requestFailed(let status, _):
            return status == 400 || status == 422
        default:
            return false
        }
    }

    private func linkToExerciseLibrary(_ source: TrainingPlan) throws -> TrainingPlan {
        var plan = source
        for dayIndex in plan.days.indices {
            for blockIndex in plan.days[dayIndex].blocks.indices {
                for exerciseIndex in plan.days[dayIndex].blocks[blockIndex].exercises.indices {
                    var exercise = plan.days[dayIndex].blocks[blockIndex].exercises[exerciseIndex]
                    let recognition = ExerciseLibraryCatalog.recognize(name: exercise.name, libraryID: exercise.libraryID)
                    switch recognition.kind {
                    case .exact, .suggested:
                        exercise.libraryID = recognition.item?.id
                        if let canonicalName = recognition.item?.name { exercise.name = canonicalName }
                    case .ambiguous, .unresolved:
                        exercise.libraryID = nil
                    }
                    exercise.libraryMatchCandidates = recognition.candidates.map(\.id)
                    exercise.libraryMatchConfidence = recognition.confidence
                    plan.days[dayIndex].blocks[blockIndex].exercises[exerciseIndex] = exercise
                }
            }
        }
        return plan
    }

    func finalizeForSaving(_ source: TrainingPlan) throws -> TrainingPlan {
        // Validate user edits before creating any custom library records.
        try PlanDocumentCodec.validate(plans: [source])
        var plan = source
        for dayIndex in plan.days.indices {
            for blockIndex in plan.days[dayIndex].blocks.indices {
                for exerciseIndex in plan.days[dayIndex].blocks[blockIndex].exercises.indices {
                    var exercise = plan.days[dayIndex].blocks[blockIndex].exercises[exerciseIndex]
                    if let item = ExerciseLibraryCatalog.item(id: exercise.libraryID) {
                        exercise.name = item.name
                    } else if let existing = ExerciseLibraryCatalog.match(name: exercise.name) {
                        exercise.libraryID = existing.id
                        exercise.name = existing.name
                    } else {
                        let custom = ExerciseLibraryItem(
                            id: "ai.\(UUID().uuidString)", name: exercise.name, aliases: [], category: .custom,
                            summary: "由 AI 导入的自定义动作，请在动作库核对并补充资料。",
                            instructions: exercise.notes.map { [$0] } ?? [], commonMistakes: [],
                            defaultTrackingMode: exercise.trackingMode,
                            defaultDurationSeconds: exercise.durationSeconds,
                            defaultRestSeconds: exercise.restSeconds,
                            videoURL: exercise.videoURL, isCustom: true,
                            safetyNotes: ["首次执行前请确认动作名称、步骤和视频是否匹配"],
                            difficulty: "待确认",
                            breathingNotes: ["保持自然呼吸，不要憋气"],
                            contraindications: ["动作资料未审核，练习前请自行确认安全性"]
                        )
                        try ExerciseLibraryCatalog.save(custom)
                        exercise.libraryID = custom.id
                    }
                    exercise.libraryMatchCandidates = nil
                    exercise.libraryMatchConfidence = nil
                    plan.days[dayIndex].blocks[blockIndex].exercises[exerciseIndex] = exercise
                }
            }
        }
        return plan
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

    static let recommendedPrompt = """
    你是 OneKeep 的训练计划结构化助手。用户已经自行决定计划，你只能整理结构，不得评价、删减、增加或擅自调整用户的训练决定。
    如果原文缺少日期、组数、休息或记录方式，不要猜测危险参数；使用最保守的结构值，并在 notes 中写明“建议用户确认”。
    保留用户写出的动作要点、左右侧、次数区间、重量、动作时长、组间休息、动作间休息和轮间休息。
    识别热身、普通训练、间歇、循环和拉伸阶段。相同动作出现在不同阶段时不要合并。
    能确定规范动作时可以返回 libraryID；不确定时保留用户原名并将 libraryID 设为 null。OneKeep 会在本地再次匹配动作库，禁止猜测 ID。
    只返回一个单行紧凑 JSON 对象，不要返回 Markdown、解释、空白缩进或重复字段。字段必须符合以下结构：
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
            "libraryID": null,
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
                let libraryID: String?
                let name: String
                let sets: Int?
                let repetitions: String?
                let weightKilograms: Double?
                let durationSeconds: Int?
                let restSeconds: Int?
                let notes: String?
                let videoURL: String?
                let trackingMode: String?

                enum CodingKeys: String, CodingKey {
                    case libraryID, name, sets, repetitions, weightKilograms, durationSeconds
                    case restSeconds, notes, videoURL, trackingMode
                }

                init(from decoder: Decoder) throws {
                    let values = try decoder.container(keyedBy: CodingKeys.self)
                    libraryID = try? values.decode(String.self, forKey: .libraryID)
                    name = try values.decode(String.self, forKey: .name)
                    sets = values.flexibleInt(.sets)
                    repetitions = values.flexibleString(.repetitions)
                    weightKilograms = values.flexibleDouble(.weightKilograms)
                    durationSeconds = values.flexibleInt(.durationSeconds)
                    restSeconds = values.flexibleInt(.restSeconds)
                    notes = values.flexibleString(.notes)
                    videoURL = try? values.decode(String.self, forKey: .videoURL)
                    trackingMode = try? values.decode(String.self, forKey: .trackingMode)
                }
            }

            let title: String
            let kind: String
            let rounds: Int?
            let restBetweenExercisesSeconds: Int?
            let restBetweenRoundsSeconds: Int?
            let exercises: [Exercise]

            enum CodingKeys: String, CodingKey {
                case title, kind, rounds, restBetweenExercisesSeconds, restBetweenRoundsSeconds, exercises
            }

            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                title = (try? values.decode(String.self, forKey: .title)) ?? "训练阶段"
                kind = try values.decode(String.self, forKey: .kind)
                rounds = values.flexibleInt(.rounds)
                restBetweenExercisesSeconds = values.flexibleInt(.restBetweenExercisesSeconds)
                restBetweenRoundsSeconds = values.flexibleInt(.restBetweenRoundsSeconds)
                exercises = try values.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
            }
        }

        let title: String
        let scheduleKind: String
        let anchorDate: String
        let weekdays: [Int]
        let blocks: [Block]

        enum CodingKeys: String, CodingKey { case title, scheduleKind, anchorDate, weekdays, blocks }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            title = (try? values.decode(String.self, forKey: .title)) ?? "训练日"
            scheduleKind = try values.decode(String.self, forKey: .scheduleKind)
            anchorDate = try values.decode(String.self, forKey: .anchorDate)
            weekdays = try values.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
            blocks = try values.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        }
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
                let exercises = block.exercises.map { exercise in
                    let libraryItem = ExerciseLibraryCatalog.item(id: exercise.libraryID, fallbackName: exercise.name)
                    let trackingMode = exercise.trackingMode.flatMap { PlannedExercise.TrackingMode(rawValue: $0) }
                        ?? libraryItem?.defaultTrackingMode
                        ?? .repetitions
                    return PlannedExercise(
                        name: exercise.name,
                        sets: max(1, exercise.sets ?? 1),
                        repetitions: exercise.repetitions,
                        plannedWeightKilograms: exercise.weightKilograms,
                        durationSeconds: exercise.durationSeconds ?? (trackingMode == .countdown ? libraryItem?.defaultDurationSeconds : nil),
                        restSeconds: max(0, exercise.restSeconds ?? libraryItem?.defaultRestSeconds ?? 0),
                        notes: exercise.notes,
                        videoURL: exercise.videoURL.flatMap(URL.init(string:)),
                        trackingMode: trackingMode,
                        libraryID: exercise.libraryID
                    )
                }
                return WorkoutBlock(
                    title: block.title,
                    kind: blockKind,
                    rounds: max(1, block.rounds ?? 1),
                    restBetweenExercisesSeconds: max(0, block.restBetweenExercisesSeconds ?? 0),
                    restBetweenRoundsSeconds: max(0, block.restBetweenRoundsSeconds ?? 0),
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

private extension KeyedDecodingContainer {
    func flexibleInt(_ key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? decode(String.self, forKey: key), let number = firstNumber(in: value) { return Int(number) }
        return nil
    }

    func flexibleDouble(_ key: Key) -> Double? {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return firstNumber(in: value) }
        return nil
    }

    func flexibleString(_ key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        return nil
    }
}

private func firstNumber(in value: String) -> Double? {
    let range = value.range(of: "[-+]?[0-9]+(?:\\.[0-9]+)?", options: .regularExpression)
    return range.flatMap { Double(String(value[$0])) }
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
