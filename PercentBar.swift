import SwiftUI
import Combine

/// A lightweight view model that throttles progress updates to 1% increments
/// to reduce UI churn and improve perceived performance.
@MainActor
final class ProgressViewModel: ObservableObject {
    
    /// Clamped 0...1 progress value, published only when it changes by at least 1%.
    @Published private(set) var progress: Double = 0

    /// Update progress from raw bytes. Publishes only on 1% increments or completion.
    func setProgress(bytesRead: Int64, totalBytes: Int64) {
        guard totalBytes > 0 else { return }
        let raw = Double(bytesRead) / Double(totalBytes)
        let rounded = (raw * 100).rounded() / 100 // 1% steps
        if rounded != progress || rounded == 1.0 {
            progress = max(0, min(1, rounded))
        }
    }

    /// Directly set a normalized 0...1 value with 1% throttling.
    func setProgress(_ value: Double) {
        let clamped = max(0, min(1, value))
        let rounded = (clamped * 100).rounded() / 100
        if rounded != progress || rounded == 1.0 {
            progress = rounded
        }
    }
}

/// A simple, efficient percent bar that animates width changes.
struct PercentBar: View {
    /// Normalized progress 0...1
    let progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.percentBarPrimaryNeon)
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.easeOut(duration: 0.12), value: progress)
            }
        }
        .frame(height: 10)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

private extension LinearGradient {
    /// A primary neon gradient for use in the percent bar.
    static var percentBarPrimaryNeon: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.green, Color.blue]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        PercentBar(progress: 0.15)
        PercentBar(progress: 0.5)
        PercentBar(progress: 0.9)
    }
    .padding()
    .background(Color.black.ignoresSafeArea())
}

