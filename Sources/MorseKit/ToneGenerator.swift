import AVFoundation

public struct Envelope {
    let rampSamples: Double
    public init(sampleRate: Double, rampMs: Double) { rampSamples = sampleRate * rampMs / 1000 }
    /// Linear attack from gate-on; used by ToneGenerator to scale amplitude near edges.
    public func gain(atSample n: Int, gateOn: Bool) -> Double {
        guard gateOn else { return 0 }
        return min(1, Double(n) / rampSamples)
    }
}

public final class ToneGenerator: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000
    private var phase: Double = 0
    private var gateOn = false
    private var gateSample = 0
    public var frequency: Double = 550
    private lazy var envelope = Envelope(sampleRate: sampleRate, rampMs: 5)

    public init() { setup() }
    private func setup() {
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let inc = 2 * Double.pi * self.frequency / self.sampleRate
            for frame in 0..<Int(frameCount) {
                let g = self.envelope.gain(atSample: self.gateSample, gateOn: self.gateOn)
                let s = Float(sin(self.phase) * g * 0.6)
                self.phase += inc; if self.phase > 2 * .pi { self.phase -= 2 * .pi }
                if self.gateOn { self.gateSample += 1 }
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
        if on {
            if !engine.isRunning { start() }
            gateSample = 0
        }
        gateOn = on
    }
}
