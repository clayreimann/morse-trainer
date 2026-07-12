import SwiftUI

/// Horizontal timing meter: shows how the last keyed element compared to the
/// target WPM. `position` is `-1...1`, where `0` means "on target", `-1` is
/// maximally slow/early and `+1` is maximally fast/late (interpretation is left
/// to the caller — this view only renders the bar).
public struct TimingMeter: View {
    public let position: Double

    private let barHeight: CGFloat = 12
    private let markerSize: CGFloat = 22

    public init(position: Double) {
        self.position = position
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange, .green, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: barHeight)

                // Center tick marking the target WPM (position == 0).
                Rectangle()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 2, height: barHeight + 10)
                    .position(x: width / 2, y: barHeight / 2)

                // Marker dot at the current position.
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                    .frame(width: markerSize, height: markerSize)
                    .shadow(radius: 2)
                    .position(x: TimingMeter.markerX(position: position, width: width), y: barHeight / 2)
            }
        }
        .frame(height: max(markerSize, barHeight + 10))
    }

    /// Pure helper mapping a clamped `position` to an x-coordinate within `width`.
    static func markerX(position: Double, width: CGFloat) -> CGFloat {
        let clamped = min(1, max(-1, position))
        return width * CGFloat((clamped + 1) / 2)
    }
}

#Preview("TimingMeter") {
    VStack(spacing: 32) {
        VStack(alignment: .leading) {
            Text("Slow (-0.5)").font(.caption)
            TimingMeter(position: -0.5)
        }
        VStack(alignment: .leading) {
            Text("On target (0)").font(.caption)
            TimingMeter(position: 0)
        }
        VStack(alignment: .leading) {
            Text("Fast (+0.6)").font(.caption)
            TimingMeter(position: 0.6)
        }
    }
    .padding()
    .frame(width: 320)
}
