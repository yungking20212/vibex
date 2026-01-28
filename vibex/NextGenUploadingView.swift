import SwiftUI

struct NextGenUploadingView: View {
    @Binding var progress: Double
    var title: String = "Uploading Your Video"
    var subtitle: String? = "Saving to your profile and creating a post"
    var onCancel: (() -> Void)? = nil

    @State private var displayedProgress: Double = 0
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    @State private var popped: Bool = false
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            GlassEffectContainer(spacing: 30.0) {
                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: displayedProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .cyan, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(rotationAngle))
                            .scaleEffect(popped ? 1.06 : 1.0)
                            .rotation3DEffect(.degrees(popped ? 12 : 0), axis: (x: 1, y: 0, z: 0))

                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseScale)
                            .glassEffect(.regular.tint(.blue).interactive(), in: .circle)

                        VStack(spacing: 4) {
                                // Small brand mark inside the spinner
                                Text("VX")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom))
                                    .shadow(color: Color.cyan.opacity(0.45), radius: 8, x: 0, y: 2)

                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .cyan.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolEffect(.bounce, value: displayedProgress)
                        }
                    }
                    .glassEffectID("uploadIcon", in: glassNamespace)

                    VStack(spacing: 12) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        if let subtitle {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Text(String(format: "%.0f%%", displayedProgress * 100))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .contentTransition(.numericText())

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.15))
                                .frame(height: 8)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, displayedProgress * 280), height: 8)
                                .overlay(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [ .clear, .white.opacity(0.6), .clear ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 50)
                                        .offset(x: shimmerOffset)
                                )
                                .animation(.spring(duration: 0.5), value: displayedProgress)
                        }
                        .frame(width: 280)

                        Text("Please don't close the app")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 32)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .glassEffectID("progressCard", in: glassNamespace)
                }
                // Cancel button
                if let onCancel {
                    Button(role: .cancel) {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            displayedProgress = progress
            startAnimations()
        }
        .onChange(of: progress) { _, newValue in
            let prev = displayedProgress
            withAnimation(.easeOut(duration: 0.6)) {
                displayedProgress = newValue
            }
            // Trigger a quick 3D pop when we pass 20%
            if prev <= 0.20 && newValue > 0.20 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { popped = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.spring()) { popped = false }
                }
            }
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            shimmerOffset = 230
        }
    }
}

// Convenience initializer for previews
extension NextGenUploadingView {
    init(progress: Binding<Double>) {
        self._progress = progress
    }
}
