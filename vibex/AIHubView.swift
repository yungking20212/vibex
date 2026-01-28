import SwiftUI
import Foundation

// MARK: - Temp shim types to fix build
// TODO: Replace with real definitions if they exist elsewhere in the project.

// Tool and UI components are provided centrally in `ai_tools`.

// MARK: - VibeX Next-Gen AI Hub (v1)
struct AIHubView: View {
    @State private var selectedTool: AITool?
    @State private var notifyEnabled: Set<AITool> = []
    @State private var animateGradient = false
    @State private var shimmerPhase: CGFloat = -120

    // New states for v2 modal
    @State private var showV2Modal: Bool = false
    @State private var v2SelectedTool: AITool? = nil
    @State private var showFunnyV2: Bool = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 14) {
                    header

                    heroCard

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AITool.allCases, id: \.self) { tool in
                            ToolCard(tool: tool) {
                                if tool == .aiFunny {
                                    showFunnyV2 = true
                                } else {
                                    v2SelectedTool = tool
                                    showV2Modal = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showV2Modal) {
            if let tool = v2SelectedTool {
                VibexAIChatView(
                    initialTool: map(tool),
                    initialUserMessage: initialMessage(for: tool),
                    autoSendOnAppear: !initialMessage(for: tool).isEmpty
                )
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Subviews
    private var background: some View {
        LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Text("AI Hub")
                .font(.largeTitle).bold()
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var heroCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to VibeX AI")
                        .font(.title2).bold()
                    Text("Choose a tool below to get started.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            )
            .padding(.horizontal, 12)
    }

    // Map project `AITool` to local `VibeXAITool` used by the chat view.
    private func map(_ tool: AITool) -> VibeXAITool {
        switch tool {
        case .chat: return .chat
        case .aiFunny: return .funny
        case .image: return .caption
        case .code: return .chat
        case .sample: return .chat
        }
    }

    // Provide a sensible initial prompt per tool so the chat can start immediately if desired.
    private func initialMessage(for tool: AITool) -> String {
        switch tool {
        case .chat:
            return "Hi! I'd like to start a general chat."
        case .aiFunny:
            return "Tell me a light, family‑friendly joke."
        case .image:
            return "Please generate a descriptive caption for an image."
        case .code:
            return "Help me with this coding question:"
        case .sample:
            return "Show me a sample interaction."
        }
    }
}
// MARK: - Preview
#Preview {
    AIHubView()
}

