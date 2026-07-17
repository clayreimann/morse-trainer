import AVFoundation

/// Linear attack/release envelope. Each sample nudges the current gain toward
/// the target (1 when gated on, 0 when off) by a fixed step, so amplitude never
/// jumps discontinuously — a jump to/from zero is what produces an audible
/// click/pop, especially on key release.
public struct Envelope {
    let step: Double
    public init(sampleRate: Double, rampMs: Double) {
        step = 1.0 / (sampleRate * rampMs / 1000)
    }
    /// Advances `current` one sample toward the gate target.
    public func next(current: Double, gateOn: Bool) -> Double {
        let target = gateOn ? 1.0 : 0.0
        if current < target { return min(target, current + step) }
        if current > target { return max(target, current - step) }
        return current
    }
}

public final class ToneGenerator: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000
    private var phase: Double = 0
    private var gateOn = false
    private var currentGain: Double = 0
    public var frequency: Double = 550
    private lazy var envelope = Envelope(sampleRate: sampleRate, rampMs: 8)

    public init() { setup() }
    private func setup() {
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let inc = 2 * Double.pi * self.frequency / self.sampleRate
            for frame in 0..<Int(frameCount) {
                self.currentGain = self.envelope.next(current: self.currentGain, gateOn: self.gateOn)
                let s = Float(sin(self.phase) * self.currentGain * 0.6)
                self.phase += inc; if self.phase > 2 * .pi { self.phase -= 2 * .pi }
                for buf in abl { (buf.mData!.assumingMemoryBound(to: Float.self))[frame] = s }
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
    }
    public func start() {
        #if os(iOS)
        // A hardware keyboard/touch app needs an active playback session or the
        // engine produces no audible output.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
        if !engine.isRunning { try? engine.start() }
    }
    public func stop() { engine.stop() }
    /// Turns the tone on/off. Starting the engine lazily here means the sidetone
    /// works on the very first key press, without requiring a prior playback.
    public func gate(_ on: Bool) {
        if on, !engine.isRunning { start() }
        gateOn = on
    }
}
