import CoreData
import SwiftUI
import UIKit

struct WorkoutView: View {
    private enum TimerPurpose {
        case exercise
        case rest
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
    @State private var persistenceError: String?

    init(trainingDay: TrainingDay) {
        self.trainingDay = trainingDay
        self.steps = WorkoutExecutionPlan.makeSteps(from: trainingDay)
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
            startSessionIfNeeded()
            prepareActualValues()
        }
        .onChange(of: stepIndex) { _ in
            prepareActualValues()
        }
        .onChange(of: timer.phase) { phase in
            guard phase == .finished, timerPurpose == .rest else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
    }

    @ViewBuilder
    private var exerciseVideo: some View {
        if let url = currentStep?.exercise.videoURL,
           let source = VideoSource(urlString: url.absoluteString) {
            ExerciseVideoView(source: source)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("退出训练")

            Spacer()

            Text(steps.isEmpty ? "0 / 0" : "\(stepIndex + 1) / \(steps.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(OKColor.secondaryText)

            Spacer()

            Menu {
                Button {
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
                Button(role: .destructive) {
                    timer.reset()
                    dismiss()
                } label: {
                    Label("退出训练", systemImage: "xmark")
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
                        Label(weight.formatted() + " kg", systemImage: "scalemass")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

                if let notes = step.exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                }
            } else {
                Text("没有可执行动作")
                    .font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .okCard()
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
                    valueField(title: "实际重量", text: $actualWeight, suffix: "kg")
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
        case .paused:
            timer.resume()
        case .idle, .finished:
            startCurrentTimer()
        }
    }

    private func startCurrentTimer() {
        if timerPurpose == .rest {
            timer.start(seconds: pendingRestSeconds)
            return
        }

        switch currentStep?.exercise.trackingMode {
        case .countdown:
            timer.start(seconds: currentStep?.exercise.durationSeconds ?? 0)
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
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        guard stepIndex + 1 < steps.count else {
            timer.reset()
            do {
                try WorkoutSessionRepository(context: managedObjectContext).finish(id: sessionID)
            } catch {
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
            timer.start(seconds: step.restAfterSeconds)
        } else {
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
        actualWeight = exercise.plannedWeightKilograms.map { String($0) } ?? ""
    }

    private func recordCurrentSet(_ step: WorkoutStep) throws {
        let duration: Int?
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
            weightKilograms: Double(actualWeight),
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
