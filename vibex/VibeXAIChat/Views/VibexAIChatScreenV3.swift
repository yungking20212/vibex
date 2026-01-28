import SwiftUI

struct VibexAIChatScreenV3: View {
    @StateObject var viewModel: VibeXAIChatViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Divider().opacity(0.12)
                messageList
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            viewModel.markUnreadIfNotAtBottom()
        }
    }

    // MARK: - Header (NO tabs)
    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "sparkles").foregroundColor(.white))

            VStack(alignment: .leading, spacing: 2) {
                Text("VibeX AI")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(viewModel.selectedTool == .chat ? "Chat • v3" : "Tool • v3")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Menu {
                Button("Chat") { viewModel.selectedTool = .chat }
                Button("Clone") { viewModel.selectedTool = .clone }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                    Text(toolName(viewModel.selectedTool))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            }

            Button {
                inputFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Messages
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages, id: \.id) { msg in
                        VibexChatBubbleV3(message: msg)
                            .id(msg.id)
                            .padding(.horizontal, 14)
                    }
                    Color.clear.frame(height: 12).id("BOTTOM")
                }
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Composer (pinned)
    private var composer: some View {
        VStack(spacing: 10) {
            if let error = viewModel.errorBanner {
                errorPill(error)
            }

            HStack(spacing: 10) {
                TextField("Message VibeX AI…", text: $viewModel.inputText, axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    )

                Button {
                    viewModel.send()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                            .shadow(color: .pink.opacity(0.35), radius: 10)

                        if viewModel.isThinking {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }

            if viewModel.hasUnreadBelow {
                Button {
                    viewModel.scrollToBottom()
                    inputFocused = true
                } label: {
                    Text("New messages ↓")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.08)), alignment: .top)
        )
    }

    private func errorPill(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .leading, endPoint: .trailing))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Button("Retry") { viewModel.retryLast() }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.black,
                     Color(red: 0.06, green: 0.05, blue: 0.14),
                     Color(red: 0.03, green: 0.02, blue: 0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(RadialGradient(colors: [Color.purple.opacity(0.30), .clear], center: .topLeading, startRadius: 20, endRadius: 420))
        .overlay(RadialGradient(colors: [Color.blue.opacity(0.22), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 420))
        .ignoresSafeArea()
    }

    private func toolName(_ tool: VibeXAITool) -> String {
        switch tool {
        case .chat: return "Chat"
        case .clone: return "Clone"
        default: return "Tool"
        }
    }
}

// Simple bubble view for v3
private struct VibexChatBubbleV3: View {
    let message: VibeXChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant { leading } else { trailing }
        }
    }

    private var leading: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay(Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundColor(.white))

            Text(message.text)
                .foregroundColor(.white.opacity(0.92))
                .font(.system(size: 16, weight: .medium))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
                )
            Spacer(minLength: 40)
        }
    }

    private var trailing: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.text)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .purple.opacity(0.25), radius: 10)
        }
    }
}

struct VibexAIChatScreenV3_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { VibexAIChatScreenV3(viewModel: VibeXAIChatViewModel(client: VibeXAIClient(functionURL: URL(string: "https://example.com")!, publishableKey: ""))) }
    }
}
