import Foundation

struct ExerciseLibraryItem: Identifiable, Codable, Hashable {
    enum VideoReviewStatus: String, Codable {
        case reviewed
        case userProvided
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case warmup
        case strength
        case cardio
        case core
        case mobility
        case cooldown
        case dumbbell
        case barbell
        case machine
        case traditional
        case custom

        var id: String { rawValue }
        var title: String {
            switch self {
            case .warmup: return "动态热身"
            case .strength: return "力量"
            case .cardio: return "有氧"
            case .core: return "核心"
            case .mobility: return "灵活与体态"
            case .cooldown: return "拉伸放松"
            case .dumbbell: return "哑铃与壶铃"
            case .barbell: return "杠铃"
            case .machine: return "拉力器与固定器械"
            case .traditional: return "传统健身"
            case .custom: return "自定义"
            }
        }
    }

    let id: String
    var name: String
    var aliases: [String]
    var category: Category
    var summary: String
    var instructions: [String]
    var commonMistakes: [String]
    var defaultTrackingMode: PlannedExercise.TrackingMode
    var defaultDurationSeconds: Int?
    var defaultRestSeconds: Int
    var videoURL: URL?
    var isCustom: Bool
    var englishName: String? = nil
    var equipment: String? = nil
    var primaryMuscles: [String]? = nil
    var safetyNotes: [String]? = nil
    var difficulty: String? = nil
    var breathingNotes: [String]? = nil
    var contraindications: [String]? = nil
    var videoAuthor: String? = nil
    var videoDurationSeconds: Int? = nil
    var alternateVideoURLs: [URL]? = nil
    var videoReviewStatus: VideoReviewStatus? = nil
    var videoReviewedAt: Date? = nil
}

enum ExerciseLibraryPreferences {
    private static let key = "onekeep.exercise-library.overrides"

    static func load(defaults: UserDefaults = .standard) -> [ExerciseLibraryItem] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ExerciseLibraryItem].self, from: data)) ?? []
    }

    static func save(_ items: [ExerciseLibraryItem], defaults: UserDefaults = .standard) throws {
        defaults.set(try JSONEncoder().encode(items), forKey: key)
    }
}

enum ExerciseLibraryCatalog {
    struct RecognitionResult {
        enum Kind { case exact, suggested, ambiguous, unresolved }
        let kind: Kind
        let item: ExerciseLibraryItem?
        let candidates: [ExerciseLibraryItem]
        let confidence: Double
    }

    static var aiNameIndex: String {
        allItems().map { item in
            item.aliases.isEmpty ? item.name : "\(item.name)（别名：\(item.aliases.joined(separator: "、"))）"
        }.joined(separator: "；")
    }

    static var aiStructuredIndex: String {
        let rows = allItems().map { item in
            AIIndexRow(
                id: item.id,
                name: item.name,
                aliases: item.aliases,
                englishName: item.englishName,
                category: item.category.rawValue,
                trackingMode: item.defaultTrackingMode.rawValue
            )
        }
        guard let data = try? JSONEncoder().encode(rows) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func allItems(defaults: UserDefaults = .standard) -> [ExerciseLibraryItem] {
        var overrides: [String: ExerciseLibraryItem] = [:]
        for item in ExerciseLibraryPreferences.load(defaults: defaults) {
            overrides[item.id] = item
        }
        let builtIns = builtInItems.map { builtIn -> ExerciseLibraryItem in
            guard var override = overrides[builtIn.id] else { return builtIn }
            // Older local overrides predate the domestic video catalog. Preserve the
            // user's edited text while filling only a missing video with the new default.
            if override.videoURL == nil { override.videoURL = builtIn.videoURL }
            if override.alternateVideoURLs == nil { override.alternateVideoURLs = builtIn.alternateVideoURLs }
            if override.videoReviewStatus == nil { override.videoReviewStatus = builtIn.videoReviewStatus }
            if override.videoReviewedAt == nil { override.videoReviewedAt = builtIn.videoReviewedAt }
            if override.difficulty == nil { override.difficulty = builtIn.difficulty }
            if override.breathingNotes == nil { override.breathingNotes = builtIn.breathingNotes }
            if override.contraindications == nil { override.contraindications = builtIn.contraindications }
            if override.videoAuthor == nil { override.videoAuthor = builtIn.videoAuthor }
            if override.videoDurationSeconds == nil { override.videoDurationSeconds = builtIn.videoDurationSeconds }
            return override
        }
        let custom = overrides.values.filter(\.isCustom).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return builtIns + custom
    }

    static func match(name: String, defaults: UserDefaults = .standard) -> ExerciseLibraryItem? {
        let normalized = normalize(name)
        return allItems(defaults: defaults).first { item in
            normalize(item.name) == normalized || item.aliases.contains { normalize($0) == normalized }
        }
    }

    static func recognize(
        name: String,
        libraryID: String? = nil,
        defaults: UserDefaults = .standard
    ) -> RecognitionResult {
        let items = allItems(defaults: defaults)
        let normalized = normalizeForRecognition(name)
        if let libraryID, let item = items.first(where: { $0.id == libraryID }) {
            let names = recognitionNames(item)
            if names.contains(normalized) {
                return RecognitionResult(kind: .exact, item: item, candidates: [item], confidence: 1)
            }
            let score = names.map { similarity(normalized, $0) }.max() ?? 0
            if score >= 0.82 {
                return RecognitionResult(kind: .suggested, item: item, candidates: [item], confidence: score)
            }
        }
        guard !normalized.isEmpty else {
            return RecognitionResult(kind: .unresolved, item: nil, candidates: [], confidence: 0)
        }
        let primaryMatches = items.filter { primaryRecognitionNames($0).contains(normalized) }
        if primaryMatches.count == 1, let item = primaryMatches.first {
            return RecognitionResult(kind: .exact, item: item, candidates: [item], confidence: 1)
        }
        if primaryMatches.count > 1 {
            return RecognitionResult(kind: .ambiguous, item: nil, candidates: Array(primaryMatches.prefix(4)), confidence: 1)
        }
        let aliasMatches = items.filter { $0.aliases.map(normalizeForRecognition).contains(normalized) }
        if aliasMatches.count == 1, let item = aliasMatches.first {
            return RecognitionResult(kind: .exact, item: item, candidates: [item], confidence: 1)
        }
        if aliasMatches.count > 1 {
            return RecognitionResult(kind: .ambiguous, item: nil, candidates: Array(aliasMatches.prefix(4)), confidence: 1)
        }

        let ranked = items.compactMap { item -> (ExerciseLibraryItem, Double)? in
            let score = recognitionNames(item).map { similarity(normalized, $0) }.max() ?? 0
            return score >= 0.72 ? (item, score) : nil
        }.sorted { lhs, rhs in
            lhs.1 == rhs.1 ? lhs.0.name.localizedStandardCompare(rhs.0.name) == .orderedAscending : lhs.1 > rhs.1
        }
        guard let best = ranked.first else {
            return RecognitionResult(kind: .unresolved, item: nil, candidates: [], confidence: 0)
        }
        let close = ranked.filter { best.1 - $0.1 <= 0.08 }.prefix(4).map(\.0)
        if close.count == 1, best.1 >= 0.82 {
            return RecognitionResult(kind: .suggested, item: best.0, candidates: [best.0], confidence: best.1)
        }
        return RecognitionResult(kind: .ambiguous, item: nil, candidates: Array(close), confidence: best.1)
    }

    static func item(id: String?, fallbackName: String? = nil) -> ExerciseLibraryItem? {
        if let id, let exact = allItems().first(where: { $0.id == id }) { return exact }
        return fallbackName.flatMap { match(name: $0) }
    }

    static func save(_ item: ExerciseLibraryItem, defaults: UserDefaults = .standard) throws {
        var overrides = ExerciseLibraryPreferences.load(defaults: defaults)
        overrides.removeAll { $0.id == item.id }
        overrides.append(item)
        try ExerciseLibraryPreferences.save(overrides, defaults: defaults)
    }

    static func removeLocalItem(id: String, defaults: UserDefaults = .standard) throws {
        var overrides = ExerciseLibraryPreferences.load(defaults: defaults)
        overrides.removeAll { $0.id == id }
        try ExerciseLibraryPreferences.save(overrides, defaults: defaults)
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "式", with: "")
            .replacingOccurrences(of: "训练", with: "")
            .replacingOccurrences(of: "运动", with: "")
    }

    private static func normalizeForRecognition(_ value: String) -> String {
        normalize(value)
            .replacingOccurrences(of: "（[^）]*）|\\([^)]*\\)|[0-9０-９]+(组|次|秒|分钟)?|每侧|左右|左侧|右侧|单侧", with: "", options: .regularExpression)
            .components(separatedBy: .punctuationCharacters).joined()
            .components(separatedBy: .symbols).joined()
    }

    private static func recognitionNames(_ item: ExerciseLibraryItem) -> Set<String> {
        Set(([item.id, item.name, item.englishName].compactMap { $0 } + item.aliases).map(normalizeForRecognition).filter { !$0.isEmpty })
    }

    private static func primaryRecognitionNames(_ item: ExerciseLibraryItem) -> Set<String> {
        Set([item.id, item.name, item.englishName].compactMap { $0 }.map(normalizeForRecognition).filter { !$0.isEmpty })
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1 }
        if lhs.contains(rhs) || rhs.contains(lhs) {
            return Double(min(lhs.count, rhs.count)) / Double(max(lhs.count, rhs.count))
        }
        let a = Array(lhs), b = Array(rhs)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, right) in b.enumerated() {
                current[j + 1] = min(
                    min(current[j] + 1, previous[j + 1] + 1),
                    previous[j] + (left == right ? 0 : 1)
                )
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }

    private struct AIIndexRow: Encodable {
        let id: String
        let name: String
        let aliases: [String]
        let englishName: String?
        let category: String
        let trackingMode: String
    }

    static let builtInItems: [ExerciseLibraryItem] = [
        item("wall-stand", "靠墙站立", ["贴墙站立"], .mobility, "用于建立头、肩胛、骨盆和脚跟的站姿参照。", ["脚跟靠近墙面，自然站直", "后脑勺、肩胛和臀部轻贴墙", "保持自然呼吸，不要刻意挺腰"], ["为了贴墙过度仰头", "腰部用力压墙"], .countdown, 60, 15),
        item("cat-cow", "猫式伸展", ["猫牛式", "猫式"], .warmup, "温和活动脊柱，适合作为训练前热身。", ["四足跪姿，手腕位于肩下", "呼气弓背，吸气缓慢展开", "在舒适范围内连续移动"], ["快速甩动颈部", "手肘锁死并耸肩"], .repetitions, nil, 15, video: "https://www.bilibili.com/video/BV1dd4y1N7RM/"),
        item("high-knees", "高抬腿", ["原地高抬腿"], .warmup, "提高心率并激活髋屈肌与下肢。", ["躯干保持直立", "交替抬膝并轻柔落地", "从低幅度开始再逐渐加快"], ["身体明显后仰", "落地声音过重"], .countdown, 30, 15, video: "https://www.bilibili.com/video/BV1H34y147Xq/"),
        item("ytwl", "YTWL训练", ["YTWL", "俯身YTWL"], .mobility, "通过四种手臂轨迹练习肩胛控制。", ["髋部后移，背部保持中立", "依次完成 Y、T、W、L 轨迹", "动作幅度以肩部舒适为准"], ["耸肩代偿", "靠惯性甩手"], .repetitions, nil, 30),
        item("plank", "平板支撑", ["前臂平板"], .core, "练习躯干抗伸展和全身稳定。", ["手肘位于肩下", "收紧腹部和臀部", "头、背、髋和腿保持一条直线"], ["塌腰", "臀部抬得过高", "屏住呼吸"], .countdown, 40, 30, video: "https://www.bilibili.com/video/BV14i421d79i/"),
        item("air-rope", "空气跳绳", ["无绳跳绳", "空跳"], .cardio, "无需器械的低门槛跳绳模拟。", ["前脚掌轻柔着地", "膝盖保持微屈", "手腕做小幅摇绳动作"], ["落地僵硬", "跳得过高", "含胸低头"], .countdown, 120, 60),
        item("chest-opener", "扩胸运动", ["扩胸"], .mobility, "在间歇休息时活动胸肩。", ["自然站立，肩部下沉", "双臂向后打开至舒适位置", "保持呼吸，不要快速弹振"], ["耸肩", "幅度过大引起肩前侧不适"], .countdown, 30, 0),
        item("bird-dog", "鸟狗式", ["鸟狗"], .core, "训练核心抗旋转和四肢协调。", ["四足跪姿并收紧腹部", "伸出对侧手臂和腿", "骨盆保持朝向地面"], ["腰部过度下沉", "身体左右摇晃"], .repetitions, nil, 15, video: "https://www.bilibili.com/video/BV1bKKVzEEHP/"),
        item("mountain-climber", "登山跑", ["登山者"], .core, "在支撑姿势中交替提膝，提高心率并训练核心。", ["双手位于肩下", "交替向胸口提膝", "先保持稳定再提高速度"], ["臀部上下弹动", "肩膀退到手腕后方"], .countdown, 30, 15),
        item("seated-knee-tuck", "坐姿收腹举腿", ["坐姿举腿", "坐姿收膝"], .core, "坐姿完成屈髋和躯干稳定练习。", ["坐在稳固椅面边缘", "双手扶稳并保持胸口打开", "屈膝靠近胸口后缓慢放回"], ["用惯性甩腿", "含胸憋气"], .repetitions, nil, 15),
        item("side-plank-hip-lift", "侧支撑抬臀", ["侧桥抬臀"], .core, "训练侧向核心和骨盆稳定。", ["手肘位于肩部正下方", "身体保持侧向直线", "控制骨盆上下移动"], ["肩部塌陷", "身体向前后翻转"], .repetitions, nil, 15),
        item("cobra", "眼镜蛇式", ["眼镜蛇伸展"], .cooldown, "温和伸展腹部和躯干前侧。", ["俯卧，双手放在胸部两侧", "利用背部与手臂轻轻抬起胸口", "骨盆保持贴地"], ["手臂强行撑到最高", "肩膀耸向耳朵"], .countdown, 30, 15),
        item("child-pose", "婴儿式", ["大拜式"], .cooldown, "用于训练后的放松和呼吸恢复。", ["跪坐并将双手向前延伸", "额头自然靠近地面", "缓慢呼吸并放松背部"], ["强压髋部", "出现膝部疼痛仍继续"], .countdown, 60, 0, video: "https://www.bilibili.com/video/BV1eD4y1m7VU/"),
        item("wall-arm-raise", "靠墙手臂上举", ["墙天使", "靠墙举手"], .mobility, "练习肩胛上旋和靠墙姿势控制。", ["背部自然靠墙站立", "双臂沿墙缓慢上举", "只在无痛范围内移动"], ["为了贴墙过度挺腰", "肩前侧疼痛仍强行上举"], .countdown, 30, 15),
        item("arm-circle", "手臂绕环", ["肩部绕环", "手臂画圈"], .warmup, "活动肩关节并逐步提高上肢温度。", ["自然站立并放松肩颈", "从小圈逐渐增加幅度", "正向和反向都要完成"], ["耸肩", "突然使用最大幅度"], .countdown, 30, 15),
        item("jumping-jack", "开合跳", ["Jumping Jack"], .cardio, "全身性热身和有氧动作。", ["微屈膝起跳并打开双腿", "双臂同步举过头顶", "轻柔落地后回到起始姿势"], ["膝盖内扣", "落地僵硬"], .countdown, 30, 30),
        item("bodyweight-squat", "徒手深蹲", ["深蹲", "自重深蹲"], .strength, "训练下肢力量和髋膝协调。", ["双脚约与肩同宽", "髋部向后下方移动", "膝盖朝脚尖方向并保持躯干稳定"], ["膝盖明显内扣", "脚跟离地", "腰背失去稳定"], .repetitions, nil, 60, video: "https://www.bilibili.com/video/BV1bX4y1K7nu/"),
        item("wall-push-up", "靠墙俯卧撑", ["墙壁俯卧撑"], .strength, "适合初学者的俯卧撑回归动作。", ["双手撑墙并略宽于肩", "身体保持直线靠近墙面", "推回时不要耸肩"], ["塌腰", "头部先靠近墙", "手肘完全外展"], .repetitions, nil, 45),
        item("push-up", "俯卧撑", ["标准俯卧撑"], .strength, "训练胸、肩、手臂和核心稳定。", ["双手略宽于肩并收紧核心", "身体整体下降至舒适深度", "推起时保持身体直线"], ["塌腰", "手肘完全外张", "颈部前伸"], .repetitions, nil, 60),
        item("glute-bridge", "臀桥", ["臀部桥"], .strength, "训练臀部发力和骨盆稳定。", ["仰卧屈膝，双脚踩稳", "收紧臀部并抬起髋部", "顶部短暂停留后控制下降"], ["用腰部过度顶起", "膝盖向外或向内散开"], .repetitions, nil, 45),
        item("reverse-lunge", "后撤弓步", ["反向弓步", "后弓步"], .strength, "训练单腿力量和平衡，通常比前跨弓步更易控制。", ["站直后单脚向后迈步", "前脚踩稳并垂直下降", "推地回到站姿后换侧"], ["前膝内扣", "步幅过窄导致失去平衡"], .repetitions, nil, 60),
        item("calf-raise", "提踵", ["站姿提踵"], .strength, "训练小腿和踝关节控制。", ["双脚平行站稳", "缓慢抬起脚跟", "在最高点停顿后控制下降"], ["脚踝向内外翻", "依靠弹跳完成"], .repetitions, nil, 30),
        item("dead-bug", "死虫式", ["Dead Bug"], .core, "训练核心抗伸展和对侧协调。", ["仰卧并抬起手臂与双腿", "收紧腹部保持腰背稳定", "缓慢伸出对侧手脚再返回"], ["腰部拱起", "动作过快"], .repetitions, nil, 15, video: "https://www.bilibili.com/video/BV1zYL8zTEcV"),
        item("superman", "超人式", ["俯卧两头起"], .core, "练习躯干后侧和肩髋协调。", ["俯卧并将手臂向前伸", "轻轻抬起手臂和双腿", "保持颈部自然后缓慢放下"], ["过度抬头", "为了高度猛抬腰部"], .repetitions, nil, 30),
        item("thoracic-rotation", "跪姿胸椎旋转", ["四足胸椎旋转", "穿针式"], .mobility, "活动胸椎旋转并减少肩颈代偿。", ["四足跪姿保持骨盆稳定", "一手放在头侧并旋转胸口", "在无痛范围内缓慢往返"], ["骨盆跟随大幅旋转", "用手强拉颈部"], .repetitions, nil, 15),
        item("hamstring-stretch", "坐姿腘绳肌拉伸", ["大腿后侧拉伸"], .cooldown, "训练后温和拉伸大腿后侧。", ["坐稳并将一侧腿伸直", "从髋部轻轻前倾", "保持背部自然并正常呼吸"], ["弓背强压身体", "膝后疼痛仍继续"], .countdown, 30, 15)
    ] + extendedItems

    private static func item(
        _ id: String,
        _ name: String,
        _ aliases: [String],
        _ category: ExerciseLibraryItem.Category,
        _ summary: String,
        _ instructions: [String],
        _ mistakes: [String],
        _ tracking: PlannedExercise.TrackingMode,
        _ duration: Int?,
        _ rest: Int,
        video: String? = nil
    ) -> ExerciseLibraryItem {
        var result = ExerciseLibraryItem(
            id: id, name: name, aliases: aliases, category: category, summary: summary,
            instructions: instructions, commonMistakes: mistakes,
            defaultTrackingMode: tracking, defaultDurationSeconds: duration,
            defaultRestSeconds: rest,
            videoURL: preferredVideo(video, id: id, category: category),
            isCustom: false,
            englishName: englishNames[id] ?? id.replacingOccurrences(of: "-", with: " ").capitalized,
            equipment: baseEquipment[id] ?? "无",
            primaryMuscles: basePrimaryMuscles[id] ?? ["全身"],
            safetyNotes: ["出现疼痛、眩晕、胸闷或动作失控时立即停止"],
            difficulty: ["push-up", "side-plank-hip-lift"].contains(id) ? "中级" : "入门",
            breathingNotes: tracking == .repetitions
                ? ["保持连续呼吸，发力阶段呼气，返回阶段吸气"]
                : ["保持自然均匀呼吸，不要憋气"],
            contraindications: ["急性损伤、明显疼痛或医生要求限制活动时暂缓练习"]
        )
        result.alternateVideoURLs = alternateTutorialVideos(for: id, category: category)
        result.videoReviewStatus = .reviewed
        result.videoReviewedAt = Self.videoCatalogReviewedAt
        return result
    }

    private static func preferredVideo(
        _ value: String?,
        id: String,
        category: ExerciseLibraryItem.Category
    ) -> URL? {
        if let value,
           let url = URL(string: value),
           url.host?.lowercased().hasSuffix("bilibili.com") == true {
            return url
        }
        return fallbackTutorialVideo(for: id, category: category) ?? value.flatMap(URL.init(string:))
    }

    private static let englishNames: [String: String] = [
        "wall-stand": "Wall Stand", "cat-cow": "Cat-Cow", "high-knees": "High Knees",
        "ytwl": "YTWL", "plank": "Forearm Plank", "air-rope": "Air Jump Rope",
        "chest-opener": "Chest Opener", "bird-dog": "Bird Dog", "mountain-climber": "Mountain Climber",
        "seated-knee-tuck": "Seated Knee Tuck", "side-plank-hip-lift": "Side Plank Hip Lift",
        "cobra": "Cobra Stretch", "child-pose": "Child's Pose", "wall-arm-raise": "Wall Arm Raise",
        "arm-circle": "Arm Circle", "jumping-jack": "Jumping Jack", "bodyweight-squat": "Bodyweight Squat",
        "wall-push-up": "Wall Push-Up", "push-up": "Push-Up", "glute-bridge": "Glute Bridge",
        "reverse-lunge": "Reverse Lunge", "calf-raise": "Calf Raise", "dead-bug": "Dead Bug",
        "superman": "Superman", "thoracic-rotation": "Quadruped Thoracic Rotation",
        "hamstring-stretch": "Seated Hamstring Stretch"
    ]

    private static let baseEquipment: [String: String] = [
        "wall-stand": "墙", "cat-cow": "垫子", "ytwl": "无或轻阻力带", "plank": "垫子",
        "bird-dog": "垫子", "mountain-climber": "垫子", "seated-knee-tuck": "稳固座椅",
        "side-plank-hip-lift": "垫子", "cobra": "垫子", "child-pose": "垫子",
        "wall-arm-raise": "墙", "wall-push-up": "墙", "dead-bug": "垫子", "superman": "垫子",
        "hamstring-stretch": "垫子"
    ]

    private static let basePrimaryMuscles: [String: [String]] = [
        "wall-stand": ["体态控制", "肩背"], "cat-cow": ["脊柱活动", "核心"],
        "high-knees": ["髋屈肌", "下肢", "心肺"], "ytwl": ["肩胛稳定肌", "肩部"],
        "plank": ["核心", "肩部"], "air-rope": ["小腿", "下肢", "心肺"],
        "chest-opener": ["胸部", "肩部"], "bird-dog": ["核心", "臀部", "背部"],
        "mountain-climber": ["核心", "髋屈肌", "心肺"], "seated-knee-tuck": ["核心", "髋屈肌"],
        "side-plank-hip-lift": ["腹斜肌", "臀中肌"], "cobra": ["腹部", "脊柱伸肌"],
        "child-pose": ["背部", "髋部"], "wall-arm-raise": ["肩部", "肩胛稳定肌"],
        "arm-circle": ["肩部"], "jumping-jack": ["全身", "心肺"],
        "bodyweight-squat": ["股四头肌", "臀部"], "wall-push-up": ["胸部", "肱三头肌"],
        "push-up": ["胸部", "肱三头肌", "核心"], "glute-bridge": ["臀部", "腘绳肌"],
        "reverse-lunge": ["臀部", "股四头肌"], "calf-raise": ["小腿"],
        "dead-bug": ["核心", "髋屈肌"], "superman": ["背部", "臀部"],
        "thoracic-rotation": ["胸椎活动", "肩部"], "hamstring-stretch": ["腘绳肌"]
    ]

    private static let videoCatalogReviewedAt = Date(timeIntervalSince1970: 1_786_464_000)
}
