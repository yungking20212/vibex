import SwiftUI

struct MovieEditorPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLength: String = "60s Short"
    @State private var prompt: String = "A gritty Chicago action story with a hero, a villain, and a twist ending…"

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("Movie Editor (Preview)")
                        .font(.title2.weight(.heavy))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Timeline preview
                VStack(alignment: .leading, spacing: 10) {
                    Text("Timeline")
                        .font(.headline)
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(1..<8) { i in
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 120, height: 76)
                                    .overlay(
                                        VStack(spacing: 6) {
                                            Image(systemName: "film")
                                                .foregroundColor(.white.opacity(0.85))
                                            Text("Scene \(i)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.white)
                                        }
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 10) {
                        Chip(title: "Trim") {}
                        Chip(title: "Replace Shot") {}
                        Chip(title: "Music") {}
                        Chip(title: "Subtitles") {}
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .padding(.horizontal, 16)

                // AI prompt panel (where AI “comes at” when user asks)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ask VibeX AI to build it")
                        .font(.headline)
                        .foregroundColor(.white)

                    Picker("Length", selection: $selectedLength) {
                        Text("60s Short").tag("60s Short")
                        Text("1-Hour Movie").tag("1-Hour Movie")
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $prompt)
                        .frame(height: 110)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))

                    Button {
                        // locked preview
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate (Coming Soon)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.purple, .pink, .blue],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("This editor is preview-only right now. Generation + earning will be enabled when Movie Maker launches.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }
}

private struct Chip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.92))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct MovieEditorPreviewScreen_Previews: PreviewProvider {
    static var previews: some View {
        MovieEditorPreviewScreen()
            .preferredColorScheme(.dark)
    }
}
