import SwiftUI

public enum SpeedRegion: Sendable { case slow, onTarget, fast }

/// Three flat pills — slow / on-target / fast — replacing the rainbow TimingMeter
/// in Learn. Only the active region's pill is filled solid; the others are muted.
public struct SpeedMeter: View {
    public let region: SpeedRegion
    public init(region: SpeedRegion) { self.region = region }
    public var body: some View {
        HStack(spacing: 8) {
            pill(.slow); pill(.onTarget); pill(.fast)
        }
        .frame(maxWidth: 180)
    }
    private func pill(_ r: SpeedRegion) -> some View {
        Capsule()
            .fill(r == region ? Color.primary : Color.primary.opacity(0.15))
            .frame(height: 6)
            .frame(maxWidth: .infinity)
    }
}

#Preview("SpeedMeter") {
    VStack(spacing: 16) {
        SpeedMeter(region: .slow); SpeedMeter(region: .onTarget); SpeedMeter(region: .fast)
    }.padding()
}
