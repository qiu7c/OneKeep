import AVFoundation

enum WorkoutAudioSession {
    static func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            // Media and speech can continue with the current route when activation fails.
        }
    }
}

@MainActor
final class WorkoutVoiceCoach {
    static let shared = WorkoutVoiceCoach()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func speak(_ text: String, enabled: Bool, volume: Double = 1) {
        guard enabled, !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        WorkoutAudioSession.activate()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.volume = Float(min(max(volume, 0), 1))
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}
