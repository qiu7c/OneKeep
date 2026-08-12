import CoreData
import SwiftUI
import UIKit

struct WorkoutView: View {
    private enum TimerPurpose {
        case exercise
        case rest
        case preparation
    }

    private struct CompletionSummary {
        let completedSets: Int
        let skippedSets: Int
        let durationSeconds: Int
        let maximumWeightKilograms: Double?
    }

    private struct UndoTransition {
        let id = UUID()
        let stepIndexes: [Int]
        let restoreIndex: Int
        let message: String
    }

    private enum WorkoutInputError: LocalizedError {
        case invalidWeight(String)

        var errorDescription: String? {
            switch self {
            case .invalidWeight(let symbol): return "请输入有效的重量（\(symbol)）"
            }
        }
    }

    let trainingDay: TrainingDay
    let steps: [WorkoutStep]
    let isResumedSession: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FocusState private var isRecordFieldFocused: Bool
    @StateObject private var timer = WorkoutTimerStore()
    @State private var stepIndex = 0
    @State private var timerPurpose: TimerPurpose = .exercise
    @State private var pendingRestSeconds = 0
    @State private var completionSummary: CompletionSummary?
    @State private var sessionID = UUID()
    @State private var hasStartedSession = false
    @State private var actualRepetitions = ""
    @State private var actualWeight = ""
    @State private var lastUsedWeight: Double?
    @State private var persistenceError: String?
    @State private var showsCancelConfirmation = false
    @State private var preferences = WorkoutPreferencesStore.load()
    @State private var announcedTenSecondWarning = false
    @State private var idleTimerStateBeforeWorkout: Bool?
    @State private var showsExitConfirmation = false
    @State private var showsSkipSetConfirmation = false
    @State private var showsSkipExerciseConfirmation = false
    @State private var videoRestartToken = 0
    @State private var actionExtensionSeconds = 0
    @State private var announcedPreparationSecond = 0
    @State private var isTransitioning = false
    @State private var undoTransition: UndoTransition?
    @State private var showsWorkoutPreparation: Bool

    init(trainingDay: TrainingDay, resumeSessionID: UUID? = nil, completedStepCount: Int = 0) {
        self.trainingDay = trainingDay
        self.steps = WorkoutExecutionPlan.makeSteps(from: trainingDay)
        self.isResumedSession = resumeSessionID != nil
        _sessionID = State(initialValue: resumeSessionID ?? UUID())
        _hasStartedSession = State(initialValue: resumeSessionID != nil)
        _showsWorkoutPreparation = State(initialValue: resumeSessionID == nil)
        let count = WorkoutExecutionPlan.makeSteps(from: trainingDay).count
        _stepIndex = State(initialValue: count == 0 ? 0 : min(max(0, completedStepCount), count - 1))
    }

    private var currentStep: WorkoutStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    var body: some View {
        Group {
            if showsWorkoutPreparation {
                workoutPreparationView
            } else if let completionSummary {
                completionView(completionSummary)
            } else {
                trainingContent
            }
        }
        .background(OKColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if !showsWorkoutPreparation { activateWorkout() }
        }
        .onChange(of: stepIndex) { _ in
            prepareActualValues()
            saveRuntime()
        }
        .onChange(of: timer.remainingSeconds) { remainingSeconds in
            saveRuntime()
            announceCountdownCueIfNeeded(remainingSeconds)
        }
        .onChange(of: timer.phase) { phase in
            saveRuntime()
            guard phase == .finished else { return }
            handleTimerFinished()
        }
        .onDisappear {
            WorkoutVoiceCoach.shared.stop()
            restoreScreenSleepSetting()
        }
        .alert("保存失败", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "未知错误")
        }
        .confirmationDialog("放弃本次训练？", isPresented: $showsCancelConfirmation, titleVisibility: .visible) {
            Button("放弃并结束记录", role: .destructive) {
                cancelWorkout()
            }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text("已完成的组仍会保留，但本次训练不会计入完成记录。")
        }
        .confirmationDialog("暂时退出训练？", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
            Button("保存进度并退出") { temporarilyExitWorkout() }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text("当前计时和训练进度会保存在本机，稍后可以从今日页面继续。")
        }
        .confirmationDialog("跳过当前组？", isPresented: $showsSkipSetConfirmation, titleVisibility: .visible) {
            Button("跳过这一组", role: .destructive) { skipCurrentSet() }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text("这一组会标记为已跳过，不会计入完成组数。")
        }
        .confirmationDialog("跳过整个动作？", isPresented: $showsSkipExerciseConfirmation, titleVisibility: .visible) {
            Button("跳过剩余组", role: .destructive) { skipCurrentExercise() }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text("当前动作尚未完成的所有组都会标记为已跳过。")
        }
    }

    private var workoutPreparationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("训练准备")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(trainingDay.title).font(.title2.bold())
                HStack(spacing: 12) {
                    completionMetric(value: "\(steps.count)", label: "训练组数")
                    completionMetric(value: "约 \(estimatedWorkoutMinutes)", label: "预计分钟")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("开始前检查", systemImage: "checklist")
                        .font(.headline)
                    LabeledContent("需要器械", value: requiredEquipment)
                    LabeledContent("缺少视频", value: "\(missingVideoCount) 个动作")
                    Text("训练期间屏幕将保持常亮，视频会遵循 Wi-Fi 和静音设置。")
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }
                .okCard()
                Button {
                    showsWorkoutPreparation = false
                    activateWorkout()
                } label: {
                    Label("开始训练", systemImage: "play.fill")
                }
                .buttonStyle(OKPrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    private var estimatedWorkoutMinutes: Int {
        let seconds = steps.reduce(0) { $0 + ($1.exercise.durationSeconds ?? 30) + $1.restAfterSeconds }
        return max(1, Int(ceil(Double(seconds) / 60)))
    }

    private var requiredEquipment: String {
        let values = steps.compactMap {
            ExerciseLibraryCatalog.item(id: $0.exercise.libraryID, fallbackName: $0.exercise.name)?.equipment
        }.filter { !$0.isEmpty && $0 != "无" }
        return Array(Set(values)).sorted().isEmpty ? "无需器械" : Array(Set(values)).sorted().joined(separator: "、")
    }

    private var missingVideoCount: Int {
        Set(steps.filter { step in
            guard let item = ExerciseLibraryCatalog.item(id: step.exercise.libraryID, fallbackName: step.exercise.name) else {
                return step.exercise.videoURL == nil
            }
            return step.exercise.videoURL == nil && ExerciseMediaResolver.playableURL(for: item) == nil
        }.map(\.exercise.id)).count
    }

    private func activateWorkout() {
        keepScreenAwake()
        preferences = WorkoutPreferencesStore.load()
        if preferences.timerNotifications { WorkoutNotificationService.requestAuthorizationIfNeeded() }
        startSessionIfNeeded()
        restoreRuntimeIfAvailable()
        prepareActualValues()
    }

    private var trainingContent: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    if isResumedSession {
                        Label("已恢复到第 \(stepIndex + 1) 组，计时状态也已恢复", systemImage: "clock.arrow.circlepath")
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .okCard()
                    }
                    exerciseVideo
                    exerciseSummary
                    actualSetInput
                }
                .padding(20)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            fixedTrainingControls
        }
    }

    @ViewBuilder
    private var exerciseVideo: some View {
        if let url = currentVideoURL,
           let source = VideoSource(urlString: url.absoluteString) {
            VStack(alignment: .trailing, spacing: 8) {
                ExerciseVideoView(
                    source: source,
                    playbackState: videoPlaybackState,
                    restartToken: videoRestartToken
                )
                    .id(url.absoluteString)
                Link(destination: url) {
                    Label("浏览器打开", systemImage: "safari")
                        .font(.caption.weight(.semibold))
                }
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var header: some View {
        HStack {
            Button {
                showsExitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("暂时退出训练")

            Spacer()

            Text(steps.isEmpty ? "0 / 0" : "\(stepIndex + 1) / \(steps.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(OKColor.secondaryText)

            Spacer()

            Menu {
                Button {
                    WorkoutNotificationService.cancel()
                    timer.reset()
                    timerPurpose = .exercise
                    pendingRestSeconds = 0
                } label: {
                    Label("重置当前计时", systemImage: "arrow.counterclockwise")
                }
                Button {
                    showsSkipSetConfirmation = true
                } label: {
                    Label("跳过当前组", systemImage: "forward.end")
                }
                .disabled(currentStep == nil || timerPurpose == .rest)
                Button {
                    showsExitConfirmation = true
                } label: {
                    Label("暂时退出", systemImage: "rectangle.portrait.and.arrow.right")
                }
                Button(role: .destructive) {
                    showsCancelConfirmation = true
                } label: {
                    Label("放弃本次训练", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("更多训练操作")
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var exerciseSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let step = currentStep {
                if timerPurpose == .rest {
                    Label("休息结束后：\(step.exercise.name)", systemImage: "forward.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(OKColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if timerPurpose == .preparation {
                    Label("准备开始", systemImage: "timer")
                        .font(.headline)
                }

                HStack {
                    Label(step.blockTitle, systemImage: blockIcon(step.blockKind))
                    Spacer()
                    if step.roundCount > 1 {
                        Text("第 \(step.roundIndex) / \(step.roundCount) 轮")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

                Text(step.exercise.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                if let side = sideLabel(for: step) {
                    Label("当前：\(side)", systemImage: "arrow.left.and.right")
                        .font(.headline)
                }

                HStack(spacing: 18) {
                    Label("第 \(step.setIndex) / \(step.setCount) 组", systemImage: "square.stack.3d.up")
                    if let repetitions = step.exercise.repetitions {
                        Label("\(repetitions) 次", systemImage: "repeat")
                    }
                    if let weight = step.exercise.plannedWeightKilograms {
                        Label(preferences.weightUnit.formatted(kilograms: weight), systemImage: "scalemass")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

                if let notes = step.exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                }

                if let libraryItem = ExerciseLibraryCatalog.item(
                    id: step.exercise.libraryID,
                    fallbackName: step.exercise.name
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("动作指导", systemImage: "list.number")
                            .font(.subheadline.weight(.semibold))
                        ForEach(Array(libraryItem.instructions.prefix(4).enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(OKColor.secondaryText)
                                Text(instruction).font(.subheadline)
                            }
                        }
                    }
                    .padding(12)
                    .background(OKColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            } else {
                Text("没有可执行动作")
                    .font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .okCard()
    }

    private var currentVideoURL: URL? {
        guard let exercise = currentStep?.exercise else { return nil }
        if let item = ExerciseLibraryCatalog.item(id: exercise.libraryID, fallbackName: exercise.name) {
            if let customURL = exercise.videoURL, customURL != item.videoURL { return customURL }
            return ExerciseMediaResolver.playableURL(for: item)
        }
        return exercise.videoURL
    }

    private var videoPlaybackState: ExerciseVideoPlaybackState {
        if timerPurpose == .rest || timerPurpose == .preparation { return .previewMuted }
        if preferences.muteExerciseVideos {
            return timer.phase == .running ? .previewMuted : .pausedMuted
        }
        return timer.phase == .running ? .playing : .paused
    }

    private var timerPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text(timerTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OKColor.secondaryText)
                Spacer()
                Text(timer.formattedTime)
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
            }

            HStack(spacing: 12) {
                if timerPurpose == .preparation {
                    timerButton(title: "立即开始", icon: "forward.fill") {
                        beginExerciseTimer()
                    }
                } else if timerPurpose == .rest {
                    timerButton(title: "-15", icon: "minus") {
                        timer.add(seconds: -15)
                    }
                } else if timer.phase != .idle {
                    timerButton(title: "重新开始", icon: "arrow.counterclockwise") {
                        beginPreparation()
                    }
                }

                if timerPurpose != .preparation {
                    timerButton(
                        title: timer.phase == .running ? "暂停" : (timer.phase == .paused ? "继续" : "开始"),
                        icon: timer.phase == .running ? "pause.fill" : "play.fill"
                    ) {
                        toggleTimer()
                    }
                }

                if timerPurpose == .rest {
                    timerButton(title: "+15", icon: "plus") {
                        timer.add(seconds: 15)
                    }
                } else if timerPurpose == .exercise,
                          currentStep?.exercise.trackingMode == .countdown,
                          timer.phase == .running || timer.phase == .paused {
                    timerButton(title: "+10", icon: "plus") {
                        timer.add(seconds: 10)
                        actionExtensionSeconds += 10
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var fixedTrainingControls: some View {
        VStack(spacing: 12) {
            if let undoTransition {
                HStack {
                    Text(undoTransition.message)
                        .font(.footnote)
                    Spacer()
                    Button("撤销") { undoLastTransition() }
                        .font(.footnote.weight(.semibold))
                }
                .padding(10)
                .background(OKColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            timerPanel
            setControls
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(OKColor.surface)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var actualSetInput: some View {
        if let step = currentStep {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timerPurpose == .rest ? "下一组记录（可选）" : "训练记录（可选）")
                        .font(.headline)
                    Text(recordHelpText(for: step))
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }

                HStack(spacing: 12) {
                    if step.exercise.trackingMode == .repetitions {
                        valueField(title: "这一组实际完成", text: $actualRepetitions, suffix: "次")
                    }
                    valueField(title: "使用的额外重量", text: $actualWeight, suffix: preferences.weightUnit.symbol)
                }

                Text("自重动作不需要填写重量；留空不会影响完成或自动计时。")
                    .font(.caption)
                    .foregroundStyle(OKColor.secondaryText)

                if let lastUsedWeight {
                    Button {
                        actualWeight = preferences.weightUnit.string(fromKilograms: lastUsedWeight)
                    } label: {
                        Label("使用上次重量 \(preferences.weightUnit.formatted(kilograms: lastUsedWeight))", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .okCard()
        }
    }

    private func valueField(title: String, text: Binding<String>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(OKColor.secondaryText)
            HStack {
                TextField("留空", text: text)
                    .keyboardType(.decimalPad)
                    .font(.title3.monospacedDigit())
                    .focused($isRecordFieldFocused)
                Text(suffix)
                    .font(.subheadline)
                    .foregroundStyle(OKColor.secondaryText)
            }
            .padding(12)
            .background(OKColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(OKColor.border, lineWidth: 0.5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var setControls: some View {
        HStack(spacing: 10) {
            if timerPurpose == .preparation {
                Label("准备姿势", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(OKColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if timerPurpose == .rest {
                Button {
                    skipRest()
                } label: {
                    Label("跳过休息", systemImage: "forward.fill")
                }
                .buttonStyle(OKPrimaryButtonStyle())
            } else if preferences.automaticWorkoutFlow,
               currentStep?.exercise.trackingMode == .countdown,
               timer.phase != .finished {
                Label("本组将自动完成", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OKColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(OKColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Button {
                    completeStep()
                } label: {
                    Label("完成本组", systemImage: "checkmark")
                }
                .buttonStyle(OKPrimaryButtonStyle())
                .disabled(currentStep == nil || timerPurpose != .exercise)
            }

            if timerPurpose == .exercise {
                Menu {
                    Button {
                        showsSkipSetConfirmation = true
                    } label: {
                        Label("跳过当前组", systemImage: "forward")
                    }
                    Button(role: .destructive) {
                        showsSkipExerciseConfirmation = true
                    } label: {
                        Label("跳过整个动作", systemImage: "forward.end")
                    }
                } label: {
                    Label("跳过", systemImage: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 84, minHeight: 48)
                        .background(OKColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(currentStep == nil)
            }
        }
    }

    private var timerTitle: String {
        if timerPurpose == .rest { return "组间休息" }
        if timerPurpose == .preparation { return "准备下一动作" }
        switch currentStep?.exercise.trackingMode {
        case .countdown: return "动作倒计时"
        case .stopwatch: return "动作正计时"
        case .repetitions, .none: return "自由计时"
        }
    }

    private func recordHelpText(for step: WorkoutStep) -> String {
        switch step.exercise.trackingMode {
        case .repetitions:
            return "填写实际做了多少次；已自动带入计划次数，可以按实际情况修改。"
        case .countdown:
            return "动作时长由计时器自动记录，这里只需在使用器械时填写实际重量。"
        case .stopwatch:
            return "练习时长由正计时自动记录，这里只需在使用器械时填写实际重量。"
        }
    }

    private func sideLabel(for step: WorkoutStep) -> String? {
        let keywords = ["单侧", "侧支撑", "侧平板", "侧卧", "弓步", "保加利亚", "单腿", "单臂"]
        guard keywords.contains(where: step.exercise.name.contains) else { return nil }
        guard step.setCount >= 2 else { return "左右两侧" }
        return step.setIndex.isMultiple(of: 2) ? "右侧" : "左侧"
    }

    private func timerButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(OKColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OKColor.border, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    private func toggleTimer() {
        switch timer.phase {
        case .running:
            timer.pause()
            WorkoutNotificationService.cancel()
        case .paused:
            timer.resume()
            announceCountdownCueIfNeeded(timer.remainingSeconds)
            if timer.mode == .countdown {
                scheduleNotification(
                    after: timer.remainingSeconds,
                    title: timerPurpose == .rest ? "休息结束" : "动作计时结束"
                )
            }
        case .idle, .finished:
            if timerPurpose == .rest {
                startRestTimer()
            } else {
                beginPreparation()
            }
        }
    }

    private func startRestTimer(announceStart: Bool = true) {
        announcedTenSecondWarning = false
        timerPurpose = .rest
        timer.start(seconds: pendingRestSeconds)
        announceCountdownCueIfNeeded(timer.remainingSeconds)
        scheduleNotification(after: pendingRestSeconds, title: "休息结束")
        if announceStart {
            speak("休息开始")
        }
    }

    private func beginPreparation() {
        guard currentStep != nil else { return }
        WorkoutNotificationService.cancel()
        isRecordFieldFocused = false
        announcedTenSecondWarning = false
        actionExtensionSeconds = 0
        announcedPreparationSecond = 3
        timerPurpose = .preparation
        timer.start(seconds: 3)
        speak("准备，3")
    }

    private func beginExerciseTimer() {
        guard let step = currentStep else { return }
        WorkoutNotificationService.cancel()
        timer.reset()
        timerPurpose = .exercise
        announcedTenSecondWarning = false
        videoRestartToken += 1
        let side = sideLabel(for: step).map { "，\($0)" } ?? ""
        speak("\(step.exercise.name)\(side)，开始")
        switch currentStep?.exercise.trackingMode {
        case .countdown:
            let seconds = currentStep?.exercise.durationSeconds ?? 0
            timer.start(seconds: seconds)
            announceCountdownCueIfNeeded(timer.remainingSeconds)
            scheduleNotification(after: seconds, title: "动作计时结束")
        case .stopwatch, .repetitions, .none:
            timer.startStopwatch()
        }
    }

    private func announceCountdownCueIfNeeded(_ remainingSeconds: Int) {
        if timerPurpose == .preparation,
           (1...2).contains(remainingSeconds),
           announcedPreparationSecond != remainingSeconds {
            announcedPreparationSecond = remainingSeconds
            speak(String(remainingSeconds))
            return
        }
        guard timer.mode == .countdown,
              timer.phase == .running,
              timerPurpose != .preparation else { return }
        if remainingSeconds == 10, !announcedTenSecondWarning {
            announcedTenSecondWarning = true
            speak(timerPurpose == .rest ? "休息还剩十秒" : "还剩十秒")
        } else if timerPurpose == .exercise, (1...3).contains(remainingSeconds) {
            speak(String(remainingSeconds))
        }
    }

    private func handleTimerFinished() {
        WorkoutNotificationService.cancel()

        if timerPurpose == .preparation {
            beginExerciseTimer()
            return
        }

        if timerPurpose == .exercise {
            guard currentStep?.exercise.trackingMode == .countdown else { return }
            if preferences.automaticWorkoutFlow {
                completeStep()
            } else {
                if preferences.hapticFeedback {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                speak("完成")
            }
            return
        }

        if preferences.hapticFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        timer.reset()
        timerPurpose = .exercise
        pendingRestSeconds = 0
        announcedTenSecondWarning = false

        if preferences.automaticWorkoutFlow {
            beginPreparation()
        } else {
            speak("休息结束")
        }
    }

    private func skipRest() {
        guard timerPurpose == .rest, !isTransitioning else { return }
        isTransitioning = true
        defer { DispatchQueue.main.async { isTransitioning = false } }
        WorkoutNotificationService.cancel()
        timer.reset()
        timerPurpose = .exercise
        pendingRestSeconds = 0
        announcedTenSecondWarning = false

        if preferences.automaticWorkoutFlow {
            beginPreparation()
        } else {
            speak("休息已跳过")
        }
        saveRuntime()
    }

    private func speak(_ text: String) {
        WorkoutVoiceCoach.shared.speak(
            text,
            enabled: preferences.voicePrompts,
            volume: preferences.voiceVolume
        )
    }

    private func completeStep(announceCompletion: Bool = true) {
        guard let step = currentStep, !isTransitioning else { return }
        isTransitioning = true
        defer { DispatchQueue.main.async { isTransitioning = false } }
        isRecordFieldFocused = false
        do {
            try recordCurrentSet(step)
        } catch {
            persistenceError = error.localizedDescription
            speak("记录未保存，请检查填写内容")
            return
        }
        if preferences.hapticFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        if announceCompletion {
            if step.restAfterSeconds > 0, preferences.autoStartRest {
                speak("完成，休息 \(step.restAfterSeconds) 秒")
            } else {
                speak("完成")
            }
        }

        advanceAfterCompletedStep(step)
    }

    private func advanceAfterCompletedStep(_ step: WorkoutStep) {
        guard stepIndex + 1 < steps.count else {
            finishWorkout()
            return
        }

        offerUndo(stepIndexes: [stepIndex], restoreIndex: stepIndex, message: "已完成本组")
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.22)) {
            stepIndex += 1
        }

        if step.restAfterSeconds > 0 {
            timerPurpose = .rest
            pendingRestSeconds = step.restAfterSeconds
            announcedTenSecondWarning = false
            if preferences.autoStartRest {
                startRestTimer(announceStart: false)
            } else {
                WorkoutNotificationService.cancel()
                timer.reset()
            }
        } else {
            WorkoutNotificationService.cancel()
            timer.reset()
            timerPurpose = .exercise
            if preferences.automaticWorkoutFlow {
                beginPreparation()
            }
        }
    }

    private func skipCurrentSet() {
        guard let step = currentStep, !isTransitioning else { return }
        isTransitioning = true
        defer { DispatchQueue.main.async { isTransitioning = false } }
        do {
            try recordSkippedSet(step, at: stepIndex)
        } catch {
            persistenceError = error.localizedDescription
            return
        }
        speak("已跳过当前组")
        if steps.indices.contains(stepIndex + 1) {
            offerUndo(stepIndexes: [stepIndex], restoreIndex: stepIndex, message: "已跳过当前组")
        }
        advanceDirectly(to: stepIndex + 1)
    }

    private func skipCurrentExercise() {
        guard let step = currentStep, !isTransitioning else { return }
        isTransitioning = true
        defer { DispatchQueue.main.async { isTransitioning = false } }
        let exerciseID = step.exercise.id
        var nextIndex = stepIndex
        do {
            while steps.indices.contains(nextIndex), steps[nextIndex].exercise.id == exerciseID {
                try recordSkippedSet(steps[nextIndex], at: nextIndex)
                nextIndex += 1
            }
        } catch {
            persistenceError = error.localizedDescription
            return
        }
        speak("已跳过 \(step.exercise.name)")
        if steps.indices.contains(nextIndex) {
            offerUndo(
                stepIndexes: Array(stepIndex..<nextIndex),
                restoreIndex: stepIndex,
                message: "已跳过 \(step.exercise.name)"
            )
        }
        advanceDirectly(to: nextIndex)
    }

    private func advanceDirectly(to nextIndex: Int) {
        WorkoutNotificationService.cancel()
        timer.reset()
        pendingRestSeconds = 0
        announcedTenSecondWarning = false
        guard steps.indices.contains(nextIndex) else {
            finishWorkout()
            return
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.22)) {
            stepIndex = nextIndex
        }
        timerPurpose = .exercise
        if preferences.automaticWorkoutFlow {
            beginPreparation()
        }
    }

    private func finishWorkout() {
        undoTransition = nil
        hasStartedSession = false
        WorkoutNotificationService.cancel()
        timer.reset()
        do {
            let summary = try makeCompletionSummary()
            try WorkoutSessionRepository(context: managedObjectContext).finish(id: sessionID)
            WorkoutRuntimeStore.clear(sessionID: sessionID)
            completionSummary = summary
        } catch {
            hasStartedSession = true
            persistenceError = error.localizedDescription
            return
        }
        speak("训练完成")
        restoreScreenSleepSetting()
    }

    private func offerUndo(stepIndexes: [Int], restoreIndex: Int, message: String) {
        let transition = UndoTransition(stepIndexes: stepIndexes, restoreIndex: restoreIndex, message: message)
        undoTransition = transition
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if undoTransition?.id == transition.id { undoTransition = nil }
        }
    }

    private func undoLastTransition() {
        guard let transition = undoTransition else { return }
        do {
            try WorkoutSessionRepository(context: managedObjectContext).deleteSets(
                sessionID: sessionID,
                stepIndexes: transition.stepIndexes
            )
        } catch {
            persistenceError = error.localizedDescription
            return
        }
        undoTransition = nil
        WorkoutNotificationService.cancel()
        timer.reset()
        timerPurpose = .exercise
        pendingRestSeconds = 0
        stepIndex = transition.restoreIndex
        speak("已撤销")
        saveRuntime()
    }

    private func makeCompletionSummary(now: Date = .now) throws -> CompletionSummary {
        let setRequest = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        setRequest.predicate = NSPredicate(format: "sessionID == %@", sessionID as NSUUID)
        let recordedSets = try managedObjectContext.fetch(setRequest)
        let skipped = recordedSets.filter { ($0.value(forKey: "isSkipped") as? NSNumber)?.boolValue ?? false }
        let weights = recordedSets.compactMap {
            guard !(($0.value(forKey: "isSkipped") as? NSNumber)?.boolValue ?? false) else { return nil }
            return ($0.value(forKey: "weightKilograms") as? NSNumber)?.doubleValue
        }

        let sessionRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        sessionRequest.fetchLimit = 1
        sessionRequest.predicate = NSPredicate(format: "id == %@", sessionID as NSUUID)
        let startedAt = try managedObjectContext.fetch(sessionRequest).first?.value(forKey: "startedAt") as? Date ?? now
        return CompletionSummary(
            completedSets: recordedSets.count - skipped.count,
            skippedSets: skipped.count,
            durationSeconds: max(0, Int(now.timeIntervalSince(startedAt))),
            maximumWeightKilograms: weights.max()
        )
    }

    private func recordSkippedSet(_ step: WorkoutStep, at recordedStepIndex: Int) throws {
        try WorkoutSessionRepository(context: managedObjectContext).recordSet(
            sessionID: sessionID,
            stepIndex: recordedStepIndex,
            step: step,
            repetitions: nil,
            weightKilograms: nil,
            durationSeconds: nil,
            isSkipped: true
        )
    }

    private func completionView(_ summary: CompletionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                    Text("训练完成")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("记录已经保存在本机")
                        .foregroundStyle(OKColor.secondaryText)
                }

                HStack(spacing: 12) {
                    completionMetric(value: "\(summary.completedSets)", label: "完成组数")
                    completionMetric(value: "\(summary.skippedSets)", label: "跳过组数")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("本次摘要", systemImage: "chart.bar")
                        .font(.headline)
                    LabeledContent("总训练时间", value: formattedDuration(summary.durationSeconds))
                    LabeledContent(
                        "最高使用重量",
                        value: summary.maximumWeightKilograms.map(preferences.weightUnit.formatted(kilograms:)) ?? "未记录"
                    )
                }
                .okCard()

                Button {
                    dismiss()
                } label: {
                    Label("返回今日", systemImage: "checkmark")
                }
                .buttonStyle(OKPrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    private func completionMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.footnote)
                .foregroundStyle(OKColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .okCard()
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "\(minutes) 分 \(remainder) 秒" : "\(remainder) 秒"
    }

    private func startSessionIfNeeded() {
        guard !hasStartedSession else { return }
        hasStartedSession = true
        do {
            try WorkoutSessionRepository(context: managedObjectContext).start(
                id: sessionID,
                trainingDay: trainingDay
            )
        } catch {
            hasStartedSession = false
            persistenceError = error.localizedDescription
        }
    }

    private func prepareActualValues() {
        guard let exercise = currentStep?.exercise else {
            actualRepetitions = ""
            actualWeight = ""
            return
        }
        if let repetitions = exercise.repetitions, let value = Int(repetitions) {
            actualRepetitions = String(value)
        } else {
            actualRepetitions = ""
        }
        actualWeight = exercise.plannedWeightKilograms.map(preferences.weightUnit.string(fromKilograms:)) ?? ""
        lastUsedWeight = fetchLastUsedWeight(for: exercise)
    }

    private func fetchLastUsedWeight(for exercise: PlannedExercise) -> Double? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        request.predicate = NSPredicate(
            format: "exerciseName == %@ AND sessionID != %@ AND weightKilograms != nil AND isSkipped == NO",
            exercise.name,
            sessionID as NSUUID
        )
        return (try? managedObjectContext.fetch(request))?.first?.value(forKey: "weightKilograms") as? Double
    }

    private func cancelWorkout() {
        WorkoutNotificationService.cancel()
        restoreScreenSleepSetting()
        hasStartedSession = false
        timer.reset()
        do {
            try WorkoutSessionRepository(context: managedObjectContext).cancel(id: sessionID)
            WorkoutRuntimeStore.clear(sessionID: sessionID)
            dismiss()
        } catch {
            hasStartedSession = true
            persistenceError = error.localizedDescription
        }
    }

    private func temporarilyExitWorkout() {
        saveRuntime()
        restoreScreenSleepSetting()
        dismiss()
    }

    private func scheduleNotification(after seconds: Int, title: String) {
        guard preferences.timerNotifications else { return }
        WorkoutNotificationService.scheduleTimerFinished(after: seconds, title: title)
    }

    private func keepScreenAwake() {
        if idleTimerStateBeforeWorkout == nil {
            idleTimerStateBeforeWorkout = UIApplication.shared.isIdleTimerDisabled
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func restoreScreenSleepSetting() {
        UIApplication.shared.isIdleTimerDisabled = idleTimerStateBeforeWorkout ?? false
    }

    private func saveRuntime() {
        guard hasStartedSession, completionSummary == nil else { return }
        let purpose: String
        switch timerPurpose {
        case .exercise: purpose = "exercise"
        case .rest: purpose = "rest"
        case .preparation: purpose = "preparation"
        }
        WorkoutRuntimeStore.save(
            WorkoutRuntimeSnapshot(
                stepIndex: stepIndex,
                timerPurpose: purpose,
                pendingRestSeconds: pendingRestSeconds,
                actionExtensionSeconds: actionExtensionSeconds,
                timer: timer.snapshot()
            ),
            sessionID: sessionID
        )
    }

    private func restoreRuntimeIfAvailable() {
        guard let snapshot = WorkoutRuntimeStore.load(sessionID: sessionID) else { return }
        stepIndex = min(max(0, snapshot.stepIndex), max(0, steps.count - 1))
        switch snapshot.timerPurpose {
        case "rest": timerPurpose = .rest
        case "preparation": timerPurpose = .preparation
        default: timerPurpose = .exercise
        }
        pendingRestSeconds = max(0, snapshot.pendingRestSeconds)
        actionExtensionSeconds = max(0, snapshot.actionExtensionSeconds ?? 0)
        timer.restore(snapshot.timer)
        if timer.phase == .running, timer.mode == .countdown {
            if timerPurpose != .preparation {
                scheduleNotification(
                    after: timer.remainingSeconds,
                    title: timerPurpose == .rest ? "休息结束" : "动作计时结束"
                )
            }
        }
    }

    private func recordCurrentSet(_ step: WorkoutStep) throws {
        let duration: Int?
        let weightKilograms: Double?
        if actualWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            weightKilograms = nil
        } else if let value = preferences.weightUnit.parseKilograms(actualWeight) {
            weightKilograms = value
        } else {
            throw WorkoutInputError.invalidWeight(preferences.weightUnit.symbol)
        }
        switch step.exercise.trackingMode {
        case .countdown:
            if timer.mode == .countdown, timer.phase != .idle {
                duration = max(0, (step.exercise.durationSeconds ?? 0) + actionExtensionSeconds - timer.remainingSeconds)
            } else {
                duration = nil
            }
        case .stopwatch, .repetitions:
            duration = timer.mode == .stopwatch ? timer.elapsedSeconds : nil
        }

        try WorkoutSessionRepository(context: managedObjectContext).recordSet(
            sessionID: sessionID,
            stepIndex: stepIndex,
            step: step,
            repetitions: Int(actualRepetitions),
            weightKilograms: weightKilograms,
            durationSeconds: duration
        )
    }

    private func blockIcon(_ kind: WorkoutBlock.Kind) -> String {
        switch kind {
        case .warmup: return "figure.cooldown"
        case .standard: return "figure.strengthtraining.traditional"
        case .interval: return "timer"
        case .circuit: return "repeat"
        case .cooldown: return "figure.flexibility"
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutView(trainingDay: TrainingPlan.preview.days[0])
    }
    .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
}
