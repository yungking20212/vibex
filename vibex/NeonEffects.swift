import SwiftUI

extension Color {
    static let deepIndigo = Color(red: Double(0x0A) / 255.0, green: Double(0x0B) / 255.0, blue: Double(0x1D) / 255.0) // #0A0B1D
    static let neonPurple = Color(red: Double(0x7B) / 255.0, green: Double(0x2F) / 255.0, blue: Double(0xF7) / 255.0) // #7B2FF7
    static let neonPink   = Color(red: Double(0xFF) / 255.0, green: Double(0x3C) / 255.0, blue: Double(0xAC) / 255.0) // #FF3CAC
    static let neonBlue   = Color(red: Double(0x2B) / 255.0, green: Double(0x8C) / 255.0, blue: Double(0xFF) / 255.0) // #2B8CFF
}

struct NeonGlow: ViewModifier {
    @ObservedObject var theme = ThemeManager.shared

    // Configurable controls
    var intensity: CGFloat = 1.0
    var spread: CGFloat = 1.0
    var palette: [Color] = [Color.neonPurple, Color.neonPink, Color.neonBlue]

    func body(content: Content) -> some View {
        content
            .modifier(
                GroupModifier { base in
                    if !theme.isNeon {
                        return AnyView(
                            base
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 6)
                        )
                    }

                    // Core layered glow
                    var view: AnyView = AnyView(
                        base
                            .shadow(color: (palette.first ?? .purple).opacity(0.24 * intensity),
                                    radius: 12 * spread, x: -6, y: 4)
                            .shadow(color: (palette.dropFirst().first ?? .pink).opacity(0.18 * intensity),
                                    radius: 22 * spread, x: 6, y: -6)
                            .shadow(color: (palette.dropFirst(2).first ?? .blue).opacity(0.16 * intensity),
                                    radius: 34 * spread, x: 0, y: 14)
                    )

                    // Outer halo for depth
                    for (idx, color) in palette.enumerated() {
                        let factor = CGFloat(idx + 1)
                        view = AnyView(
                            view.shadow(
                                color: color.opacity(0.08 * intensity / factor),
                                radius: (40 + 10 * factor) * spread,
                                x: 0, y: 2 * factor
                            )
                        )
                    }

                    // Slight lift
                    return AnyView(view.scaleEffect(1.01 + 0.005 * intensity))
                }
            )
    }
}

private struct GroupModifier: ViewModifier {
    let transform: (SwiftUI.AnyView) -> SwiftUI.AnyView

    init(@ViewBuilder transform: @escaping (SwiftUI.AnyView) -> SwiftUI.AnyView) {
        self.transform = transform
    }

    func body(content: Self.Content) -> some View {
        // Wrap incoming content in AnyView so both branches return the same type
        transform(AnyView(content))
    }
}

extension View {
    func neonGlow(
        intensity: CGFloat = 1.0,
        spread: CGFloat = 1.0,
        palette: [Color] = [Color.neonPurple, Color.neonPink, Color.neonBlue]
    ) -> some View {
        modifier(NeonGlow(intensity: intensity, spread: spread, palette: palette))
    }
}

// Pulsing bloom — subtle scale + glow animation for Neon accents
struct PulsingBloom: ViewModifier {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false
    @State private var phase: CGFloat = 0
    @State private var timer: Timer? = nil

    var scale: CGFloat = 1.04
    var glowRadius: CGFloat = 30
    var brightness: CGFloat = 0.06

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if theme.isNeon {
                        content
                            .blur(radius: pulse ? glowRadius : glowRadius * 0.4)
                            .brightness(pulse ? brightness : 0)
                            .blendMode(.screen)
                            .offset(x: sin(phase) * 0.8, y: cos(phase) * 0.8)
                            .allowsHitTesting(false)
                    } else {
                        EmptyView()
                    }
                }
            )
            .scaleEffect(theme.isNeon && !reduceMotion ? (pulse ? scale : 1.0) : 1.0)
            .onAppear {
                guard theme.isNeon else { return }
                if reduceMotion {
                    pulse = true
                    phase = 0
                } else {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulse.toggle()
                    }

                    // Invalidate any previous timer to avoid duplicates
                    timer?.invalidate()
                    // Snapshot values on the main actor to avoid cross-actor access
                    let initialIsNeon: Bool = {
                        // Accessing theme.isNeon on the main actor
                        return ThemeManager.shared.isNeon
                    }()
                    let reduce = reduceMotion
                    // Schedule timer; avoid capturing the non-Sendable parameter by not using it
                    // and perform UI updates on the main thread directly.
                    timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak theme] _ in
                        Task { @MainActor in
                            // Re-check theme on the main actor to respect isolation
                            let currentIsNeon = theme?.isNeon ?? false
                            if !(initialIsNeon && currentIsNeon) || reduce {
                                self.timer?.invalidate()
                                self.timer = nil
                                return
                            }
                            self.phase += 0.05
                        }
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

extension View {
    func pulsingBloom(
        scale: CGFloat = 1.04,
        glowRadius: CGFloat = 30,
        brightness: CGFloat = 0.06
    ) -> some View {
        modifier(PulsingBloom(scale: scale, glowRadius: glowRadius, brightness: brightness))
    }
}
struct GlassySurface: ViewModifier {
    var cornerRadius: CGFloat = 16
    var opacity: CGFloat = 0.18

    func body(content: Content) -> some View {
        content
            .background(
                Color.white.opacity(opacity)
                    .blendMode(.plusLighter)
                    .blur(radius: 6)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glassySurface(cornerRadius: CGFloat = 16, opacity: CGFloat = 0.18) -> some View {
        modifier(GlassySurface(cornerRadius: cornerRadius, opacity: opacity))
    }
}

extension LinearGradient {
    static var primaryNeon: LinearGradient {
        LinearGradient(colors: [.neonPurple, .neonPink, .neonBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
struct SoftOutline: ViewModifier {
    var cornerRadius: CGFloat = 12
    var lineWidth: CGFloat = 1
    var opacity: CGFloat = 0.1 // ~10%

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(opacity), lineWidth: lineWidth)
            )
    }
}

extension View {
    func softOutline(cornerRadius: CGFloat = 12, lineWidth: CGFloat = 1, opacity: CGFloat = 0.1) -> some View {
        modifier(SoftOutline(cornerRadius: cornerRadius, lineWidth: lineWidth, opacity: opacity))
    }
}

