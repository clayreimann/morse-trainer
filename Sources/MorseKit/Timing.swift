public struct TimingSettings: Equatable, Sendable {
    public var charWPM: Double
    public var effectiveWPM: Double
    public var wordSpacing: Double
    public init(charWPM: Double, effectiveWPM: Double, wordSpacing: Double) {
        self.charWPM = charWPM; self.effectiveWPM = effectiveWPM; self.wordSpacing = wordSpacing
    }
}

public struct ToneEvent: Equatable, Sendable {
    public let on: Bool          // true = tone, false = silence
    public let duration: Double  // ms
    public init(on: Bool, duration: Double) { self.on = on; self.duration = duration }
}

public enum Timing {
    public static func unitMs(charWPM: Double) -> Double { 1200.0 / charWPM }

    public static func schedule(for text: String, settings s: TimingSettings) -> [ToneEvent] {
        let u = unitMs(charWPM: s.charWPM)
        // Farnsworth: compute stretch for standard 3u/7u gaps.
        // Total standard units in the string = element+intra units + 3u*(interChar) + 7u*(interWord).
        // We stretch only the gap portion so total time == time at effectiveWPM.
        let chars = Array(text.uppercased())
        // Precompute element on/off (intra) events per character + count gaps.
        var elementUnits = 0.0
        var interCharCount = 0
        var interWordCount = 0
        var perChar: [[ToneEvent]] = []
        for (i, c) in chars.enumerated() {
            if c == " " {
                interWordCount += 1
                perChar.append([]) // marker; gap emitted below
                continue
            }
            guard let code = MorseCode.code(for: c) else { perChar.append([]); continue }
            var evs: [ToneEvent] = []
            for (j, sym) in code.enumerated() {
                let onU = sym == .dot ? 1.0 : 3.0
                elementUnits += onU
                evs.append(ToneEvent(on: true, duration: onU * u))
                if j < code.count - 1 { evs.append(ToneEvent(on: false, duration: u)); elementUnits += 1 }
            }
            perChar.append(evs)
            // count an inter-char gap if the next non-space char is a letter (not word break/end)
            if i < chars.count - 1 && chars[i+1] != " " { interCharCount += 1 }
        }
        // Standard gap units and Farnsworth-stretched gap unit sizes.
        let stdGapUnits = Double(interCharCount) * 3 + Double(interWordCount) * 7
        let standardTotalUnits = elementUnits + stdGapUnits
        let targetTotalMs = standardTotalUnits * unitMs(charWPM: s.effectiveWPM)
        let elementMs = elementUnits * u
        let extraGapMs = max(0, targetTotalMs - elementMs)   // total ms available for gaps
        // Distribute in 3:7 ratio to inter-char vs inter-word gap *slots*.
        let charGapWeight = Double(interCharCount) * 3
        let wordGapWeight = Double(interWordCount) * 7
        let weight = charGapWeight + wordGapWeight
        let interCharGapMs: Double = interCharCount == 0 ? 0 :
            (weight == 0 ? 0 : extraGapMs * (charGapWeight / weight) / Double(interCharCount))
        var interWordGapMs: Double = interWordCount == 0 ? 0 :
            (weight == 0 ? 0 : extraGapMs * (wordGapWeight / weight) / Double(interWordCount))
        interWordGapMs *= s.wordSpacing
        // Emit with gaps between characters/words.
        var out: [ToneEvent] = []
        for (i, evs) in perChar.enumerated() {
            if chars[i] == " " {
                out.append(ToneEvent(on: false, duration: interWordGapMs)); continue
            }
            out.append(contentsOf: evs)
            if i < chars.count - 1 && chars[i+1] != " " {
                out.append(ToneEvent(on: false, duration: interCharGapMs))
            }
        }
        return out
    }
}
