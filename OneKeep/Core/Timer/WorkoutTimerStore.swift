import Combine
import Foundation

@MainActor
final class WorkoutTimerStore: ObservableObject {
    struct Snapshot: Codable {
        let mode: String
        let phase: String
        let remainingSeconds: Int
        let elapsedSeconds: Int
        let endDate: Date?
        let pausedSeconds: Int
        let stopwatchStartDate: Date?
        let accumulatedElapsedSeconds: Int
    }
    enum Mode: Equatable {
        case countdown
        case stopwatch
    }

    enum Phase: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var mode: Mode = .countdown
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var elapsedSeconds = 0

    private var endDate: Date?
    private var pausedSeconds = 0
    private var stopwatchStartDate: Date?
    private var accumulatedElapsedSeconds = 0
    private var ticker: AnyCancellable?

    init() {
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.update(now: now)
            }
    }

    var formattedTime: String {
        let value = mode == .countdown ? remainingSeconds : elapsedSeconds
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(seconds: Int, now: Date = .now) {
        mode = .countdown
        stopwatchStartDate = nil
        accumulatedElapsedSeconds = 0
        elapsedSeconds = 0
        let safeSeconds = max(0, seconds)
        remainingSeconds = safeSeconds
        pausedSeconds = safeSeconds

        guard safeSeconds > 0 else {
            phase = .finished
            endDate = nil
            return
        }

        endDate = now.addingTimeInterval(TimeInterval(safeSeconds))
        phase = .running
    }

    func startStopwatch(now: Date = .now) {
        mode = .stopwatch
        endDate = nil
        pausedSeconds = 0
        remainingSeconds = 0
        accumulatedElapsedSeconds = 0
        elapsedSeconds = 0
        stopwatchStartDate = now
        phase = .running
    }

    func pause(now: Date = .now) {
        guard phase == .running else { return }
        update(now: now)
        if mode == .countdown {
            pausedSeconds = remainingSeconds
            endDate = nil
            phase = remainingSeconds > 0 ? .paused : .finished
        } else {
            accumulatedElapsedSeconds = elapsedSeconds
            stopwatchStartDate = nil
            phase = .paused
        }
    }

    func resume(now: Date = .now) {
        guard phase == .paused else { return }
        if mode == .countdown {
            guard pausedSeconds > 0 else { return }
            remainingSeconds = pausedSeconds
            endDate = now.addingTimeInterval(TimeInterval(pausedSeconds))
            phase = .running
        } else {
            stopwatchStartDate = now
            phase = .running
        }
    }

    func add(seconds: Int, now: Date = .now) {
        guard mode == .countdown else { return }
        let updated = max(0, remainingSeconds + seconds)
        remainingSeconds = updated
        pausedSeconds = updated

        if phase == .running {
            endDate = now.addingTimeInterval(TimeInterval(updated))
        } else if updated == 0 {
            phase = .finished
        }
    }

    func reset() {
        endDate = nil
        stopwatchStartDate = nil
        pausedSeconds = 0
        accumulatedElapsedSeconds = 0
        remainingSeconds = 0
        elapsedSeconds = 0
        mode = .countdown
        phase = .idle
    }

    func snapshot() -> Snapshot {
        Snapshot(
            mode: mode == .countdown ? "countdown" : "stopwatch",
            phase: phaseName,
            remainingSeconds: remainingSeconds,
            elapsedSeconds: elapsedSeconds,
            endDate: endDate,
            pausedSeconds: pausedSeconds,
            stopwatchStartDate: stopwatchStartDate,
            accumulatedElapsedSeconds: accumulatedElapsedSeconds
        )
    }

    func restore(_ snapshot: Snapshot, now: Date = .now) {
        mode = snapshot.mode == "stopwatch" ? .stopwatch : .countdown
        phase = restoredPhase(from: snapshot.phase)
        remainingSeconds = max(0, snapshot.remainingSeconds)
        elapsedSeconds = max(0, snapshot.elapsedSeconds)
        endDate = snapshot.endDate
        pausedSeconds = max(0, snapshot.pausedSeconds)
        stopwatchStartDate = snapshot.stopwatchStartDate
        accumulatedElapsedSeconds = max(0, snapshot.accumulatedElapsedSeconds)
        update(now: now)
    }

    private var phaseName: String {
        switch phase {
        case .idle: return "idle"
        case .running: return "running"
        case .paused: return "paused"
        case .finished: return "finished"
        }
    }

    private func restoredPhase(from value: String) -> Phase {
        switch value {
        case "running": return .running
        case "paused": return .paused
        case "finished": return .finished
        default: return .idle
        }
    }

    func update(now: Date) {
        guard phase == .running else { return }

        if mode == .countdown, let endDate {
            let seconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
            remainingSeconds = seconds

            if seconds == 0 {
                pausedSeconds = 0
                self.endDate = nil
                phase = .finished
            }
        } else if mode == .stopwatch, let stopwatchStartDate {
            let runningSeconds = max(0, Int(floor(now.timeIntervalSince(stopwatchStartDate))))
            elapsedSeconds = accumulatedElapsedSeconds + runningSeconds
        }
    }
}
