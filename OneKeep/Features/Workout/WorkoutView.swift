import CoreData
import SwiftUI
import UIKit

struct WorkoutView: View {
    private enum TimerPurpose {
        case exercise
        case rest
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var timer = WorkoutTimerStore()
    @State private var stepIndex = 0
    @State private var timerPurpose: TimerPurpose = .exercise
    @State private var pendingRestSeconds = 0
    @State private var showsCompletion = false
    @State private var sessionID = UUID()
    @State private var hasStartedSession = false
    @State private var actualRepetitions = ""
    @State private var actualWeight = ""
    @State private var lastUsedWeight: Double?
    @State private var persistenceError: String?
    @State private var showsCancelConfirmation = false
    @State private var preferences = WorkoutPreferencesStore.load()

    init(trainingDay: TrainingDay, resumeSessionID: UUID? = nil, completedStepCount: Int = 0) {
        self.trainingDay = trainingDay
        self.steps = WorkoutExecutionPlan.makeSteps(from: trainingDay)
        _sessionID = State(initialValue: resumeSessionID ?? UUID())
        _hasStartedSession = State(initialValue: resumeSessionID != nil)
        let count = WorkoutExecutionPlan.makeSteps(from: trainingDay).count
        _stepIndex = State(initialValue: count == 0 ? 0 : min(max(0, completedStepCount), count - 1))
    }

    private var currentStep: WorkoutStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 20) {
                    exerciseVideo
                    exerciseSummary
                    actualSetInput
                    timerPanel
                    setControls
                }
                .padding(20)
            }
        }
        .background(OKColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            preferences = WorkoutPreferencesStore.load()
            if preferences.timerNotifications {
                WorkoutNotificationService.requestAuthorizationIfNeeded()
            }
            startSessionIfNeeded()
            restoreRuntimeIfAvailable()
            prepareActualValues()
        }
        .onChange(of: stepIndex) { _ in
            prepareActualValues()
            saveRuntime()
        }
        .onChange(of: timer.remainingSeconds) { _ in
            saveRuntime()
        }
        .onChange(of: timer.phase) { phase in
            saveRuntime()
            guard phase == .finished else { return }
            if preferences.hapticFeedback {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            WorkoutNotificationService.cancel()
            guard timerPurpose == .rest else { return }
            DispatchQueue.main.async {
                timer.reset()
                timerPurpose = .exercise
                pendingRestSeconds = 0
            }
        }
        .alert("训练完成", isPresented: $showsCompletion) {
            Button("完成") {
                dismiss()
            }
        } message: {
            Text("本次训练记录已准备保存。")
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
    }

    @ViewBuilder
    private var exerciseVideo: some View {
        if let url = currentVideoURL,
           let source = VideoSource(urlString: url.absoluteString) {
            VStack(alignment: .trailing, spacing: 8) {
                ExerciseVideoView(source: source)
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
                saveRuntime()
                dismiss()
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
                    completeStep()
                } label: {
                    Label("跳过当前组", systemImage: "forward.end")
                }
                .disabled(currentStep == nil || timerPurpose == .rest)
                Button {
                    saveRuntime()
                    dismiss()
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
                    Divider()
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

    private var timerPanel: some View {
        VStack(spacing: 18) {
            Text(timerTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OKColor.secondaryText)

            Text(timer.formattedTime)
                .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())

            HStack(spacing: 12) {
                if timer.mode == .countdown {
                    timerButton(title: "-15", icon: "minus") {
                        timer.add(seconds: -15)
                    }
                } else {
                    timerButton(title: "归零", icon: "arrow.counterclockwise") {
                        timer.reset()
                    }
                }

                timerButton(
                    title: timer.phase == .running ? "暂停" : (timer.phase == .paused ? "继续" : "开始"),
                    icon: timer.phase == .running ? "pause.fill" : "play.fill"
                ) {
                    toggleTimer()
                }

                if timer.mode == .countdown {
                    timerButton(title: "+15", icon: "plus") {
                        timer.add(seconds: 15)
                    }
                } else {
                    timerButton(title: "停止", icon: "stop.fill") {
                        timer.reset()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .okCard()
    }

    @ViewBuilder
    private var actualSetInput: some View {
        if let step = currentStep {
            VStack(alignment: .leading, spacing: 14) {
                Text("本组记录")
                    .font(.headline)

                HStack(spacing: 12) {
                    if step.exercise.trackingMode == .repetitions {
                        valueField(title: "实际次数", text: $actualRepetitions, suffix: "次")
                    }
                    valueField(title: "实际重量", text: $actualWeight, suffix: preferences.weightUnit.symbol)
                }

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
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.title3.monospacedDigit())
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
        VStack(spacing: 12) {
            Button {
                completeStep()
            } label: {
                Label("完成本组", systemImage: "checkmark")
            }
            .buttonStyle(OKPrimaryButtonStyle())
            .disabled(currentStep == nil || timerPurpose == .rest)

            Button("跳过当前组") {
                completeStep()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(OKColor.secondaryText)
            .frame(minHeight: 44)
            .disabled(currentStep == nil || timerPurpose == .rest)
        }
    }

    private var timerTitle: String {
        if timerPurpose == .rest { return "组间休息" }
        switch currentStep?.exercise.trackingMode {
        case .countdown: return "动作倒计时"
        case .stopwatch: return "动作正计时"
        case .repetitions, .none: return "自由计时"
        }
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
            if timer.mode == .countdown {
                scheduleNotification(
                    after: timer.remainingSeconds,
                    title: timerPurpose == .rest ? "休息结束" : "动作计时结束"
                )
            }
        case .idle, .finished:
            startCurrentTimer()
        }
    }

    private func startCurrentTimer() {
        if timerPurpose == .rest {
            timer.start(seconds: pendingRestSeconds)
            scheduleNotification(after: pendingRestSeconds, title: "休息结束")
            return
        }

        switch currentStep?.exercise.trackingMode {
        case .countdown:
            let seconds = currentStep?.exercise.durationSeconds ?? 0
            timer.start(seconds: seconds)
            scheduleNotification(after: seconds, title: "动作计时结束")
        case .stopwatch, .repetitions, .none:
            timer.startStopwatch()
        }
    }

    private func completeStep() {
        guard let step = currentStep else { return }
        do {
            try recordCurrentSet(step)
        } catch {
            persistenceError = error.localizedDescription
            return
        }
        if preferences.hapticFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        guard stepIndex + 1 < steps.count else {
            hasStartedSession = false
            timer.reset()
            do {
                try WorkoutSessionRepository(context: managedObjectContext).finish(id: sessionID)
                WorkoutRuntimeStore.clear(sessionID: sessionID)
            } catch {
                hasStartedSession = true
                persistenceError = error.localizedDescription
                return
            }
            showsCompletion = true
            return
        }

        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.22)) {
            stepIndex += 1
        }

        if step.restAfterSeconds > 0 {
            timerPurpose = .rest
            pendingRestSeconds = step.restAfterSeconds
            if preferences.autoStartRest {
                timer.start(seconds: step.restAfterSeconds)
                scheduleNotification(after: step.restAfterSeconds, title: "休息结束")
            } else {
                WorkoutNotificationService.cancel()
                timer.reset()
            }
        } else {
            WorkoutNotificationService.cancel()
            timer.reset()
            timerPurpose = .exercise
        }
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
            format: "exerciseName == %@ AND sessionID != %@ AND weightKilograms != nil",
            exercise.name,
            sessionID as NSUUID
        )
        return (try? managedObjectContext.fetch(request))?.first?.value(forKey: "weightKilograms") as? Double
    }

    private func cancelWorkout() {
        WorkoutNotificationService.cancel()
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

    private func scheduleNotification(after seconds: Int, title: String) {
        guard preferences.timerNotifications else { return }
        WorkoutNotificationService.scheduleTimerFinished(after: seconds, title: title)
    }

    private func saveRuntime() {
        guard hasStartedSession, !showsCompletion else { return }
        WorkoutRuntimeStore.save(
            WorkoutRuntimeSnapshot(
                stepIndex: stepIndex,
                timerPurpose: timerPurpose == .rest ? "rest" : "exercise",
                pendingRestSeconds: pendingRestSeconds,
                timer: timer.snapshot()
            ),
            sessionID: sessionID
        )
    }

    private func restoreRuntimeIfAvailable() {
        guard let snapshot = WorkoutRuntimeStore.load(sessionID: sessionID) else { return }
        stepIndex = min(max(0, snapshot.stepIndex), max(0, steps.count - 1))
        timerPurpose = snapshot.timerPurpose == "rest" ? .rest : .exercise
        pendingRestSeconds = max(0, snapshot.pendingRestSeconds)
        timer.restore(snapshot.timer)
        if timer.phase == .running, timer.mode == .countdown {
            scheduleNotification(
                after: timer.remainingSeconds,
                title: timerPurpose == .rest ? "休息结束" : "动作计时结束"
            )
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
                duration = max(0, (step.exercise.durationSeconds ?? 0) - timer.remainingSeconds)
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
