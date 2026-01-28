import SwiftUI

// MARK: - VibeX AI Studio (Chat-First)
struct VibexAIStudioView: View {
    @State private var selectedTool: VibeXAITool = .chat
    @State private var input: String = ""
    @State private var openChat: Bool = false

    // when user taps a suggested prompt, we pass it into the chat as the first message
    @State private var pendingPromptToSend: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        header

                        subtitle

                        composer

                        toolModes

                        suggestedSection

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 14)
                }
            }
            .navigationDestination(isPresented: $openChat) {
                VibexAIChatView(
                    initialTool: selectedTool,
                    initialUserMessage: pendingPromptToSend ?? input.trimmingCharacters(in: .whitespacesAndNewlines),
                    autoSendOnAppear: (pendingPromptToSend != nil) || !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .onAppear {
                    // clear after navigation
                    input = ""
                    pendingPromptToSend = nil
                }
            }
        }
    }

    // MARK: - Background
    private var background: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.35),
                Color.blue.opacity(0.20),
                Color.black.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            RadialGradient(colors: [Color.white.opacity(0.10), .clear],
                           center: .topLeading,
                           startRadius: 10,
                           endRadius: 420)
            .ignoresSafeArea()
        )
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center) {
            Text("VibeX AI")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [Color.purple.opacity(0.95), Color.cyan.opacity(0.95)],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )

            Text("✨")
                .font(.system(size: 30))

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.6), radius: 8)
                Text("Online")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .padding(.horizontal, 14)
    }

    private var subtitle: some View {
        HStack {
            Text("All your AI agents and tools in one place")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.70))
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Composer
    private var composer: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedTool.icon)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

            TextField("Ask VibeX anything…", text: $input, axis: .vertical)
                .lineLimit(1...3)
                .foregroundStyle(.white)
                .submitLabel(.send)
                .onSubmit { goSend() }

            Button {
                // v1: mic UI only (you can connect speech later)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }

            Button {
                goSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.90)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    // MARK: - Tool Modes
    private var toolModes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tool Modes")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VibeXAITool.allCases, id: \.self) { tool in
                        ModeChip(
                            title: tool.rawValue,
                            icon: tool.icon,
                            isSelected: tool == selectedTool
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedTool = tool
                            }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Suggested
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent / Suggested")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)

            VStack(spacing: 10) {
                ForEach(suggestions(for: selectedTool), id: \.self) { s in
                    SuggestionRow(
                        icon: selectedTool.icon,
                        title: s
                    ) {
                        pendingPromptToSend = s
                        openChat = true
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func goSend() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingPromptToSend = nil
        openChat = true
    }

    private func suggestions(for tool: VibeXAITool) -> [String] {
        switch tool {
        case .funny:
            return [
                "Make a funny TikTok caption for: (paste your video idea)",
                "Turn this message into a viral joke: (paste text)",
                "Write 10 funny hooks for my video topic: (topic)"
            ]
        case .caption:
            return [
                "Generate an album cover with smoke + neon purple + money flying",
                "Create a logo concept for VibeX AI Studio (clean + futuristic)",
                "Make 4 thumbnail ideas for my video: (topic)"
            ]
        case .chat:
            return [
                "Fix my SwiftUI layout issue: (paste code)",
                "Build a next-gen chat UI with tool modes + typing indicator",
                "Convert this cURL call to Swift URLSession: (paste curl)"
            ]
        case .clone:
            return [
                "Clone my video style: fast cuts, captions, punchlines (describe style)",
                "Rewrite this script in my style: (paste script)",
                "Make my caption sound like my brand voice: (describe voice)"
            ]
        case .story:
            return [
                "Create a movie pitch + plot twist for: (idea)",
                "Write a trailer script with voiceover for: (idea)",
                "Give me 10 movie titles for: (theme)"
            ]
        case .story:
            return [
                "Create a TV show bible for: (idea)",
                "Write episode 1 outline + cliffhanger for: (show concept)",
                "Create 5 characters + arcs for: (genre)"
            ]
        case .musicVideo:
            return [
                "Write a hook + chorus idea for: (song vibe)",
                "Give me 10 music video concepts for: (song theme)",
                "Create a rollout plan for my song: (genre + goal)"
            ]
        case .boost:
            return [
                "Build me a daily plan to hit my goals: (goals + time)",
                "Help me make a money plan: (income + bills)",
                "Write a clean bio for my profile: (who you are)"
            ]
        default:
            return [
                "Make a funny TikTok caption",
                "Generate an image idea",
                "Fix SwiftUI code"
            ]
        }
    }
}

// MARK: - Chip + Row
private struct ModeChip: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.90))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: isSelected ? Color.white.opacity(0.12) : .clear, radius: 12, x: 0, y: 8)
        .opacity(isSelected ? 1.0 : 0.88)
    }
}

private struct SuggestionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

                Text(title)
                    .foregroundStyle(.white.opacity(0.90))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

