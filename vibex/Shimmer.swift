import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    var speed: Double = 1.0
    var angle: Angle = .init(degrees: 70)

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    let gradient = LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.06), location: 0),
                            .init(color: Color.white.opacity(0.12), location: 0.5),
                            .init(color: Color.white.opacity(0.06), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Rectangle()
                        .fill(gradient)
                        .rotationEffect(angle)
                        .offset(x: proxy.size.width * phase)
                        .blendMode(.overlay)
                        .mask(content)
                        .onAppear {
                            withAnimation(.linear(duration: 1.2 / speed).repeatForever(autoreverses: false)) {
                                phase = 1.0
                            }
                        }
                }
            )
    }
}

extension View {
    func shimmer(speed: Double = 1.0, angle: Angle = .init(degrees: 70)) -> some View {
        modifier(Shimmer(speed: speed, angle: angle))
    }
}
