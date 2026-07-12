import Foundation

public final class MorsePlayer: @unchecked Sendable {
    private let tone: ToneGenerator
    public init(tone: ToneGenerator) { self.tone = tone }

    public func buildSchedule(for text: String, settings: TimingSettings) -> [ToneEvent] {
        Timing.schedule(for: text, settings: settings)
    }

    /// Plays the schedule. `onCharBoundary` fires with the index of the character just completed.
    public func play(_ text: String, settings: TimingSettings,
                     frequency: Double = 550,
                     onCharBoundary: @escaping @Sendable (Int) -> Void = { _ in },
                     completion: @escaping @Sendable () -> Void = {}) {
        tone.frequency = frequency
        tone.start()
        let schedule = buildSchedule(for: text, settings: settings)
        var t = 0.0
        for ev in schedule {
            let on = ev.on
            DispatchQueue.main.asyncAfter(deadline: .now() + t/1000) { self.tone.gate(on) }
            t += ev.duration
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + t/1000) {
            self.tone.gate(false); completion()
        }
    }
    public func stop() { tone.gate(false); tone.stop() }
}
