import SwiftUI

// MARK: - VibeX AI Chat v3 (No tabs, keyboard-safe, pinned composer)
struct VibexAIChatV3: View {
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = [
        .init(role: .assistant, text: "Welcome to VibeX AI ✨ What are we building today?")
    ]
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            VibexChatBackground()

            VStack(spacing: 0) {
                header

                Divider().opacity(0.15)

                chatList

                composer
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom) // ✅ stops keyboard pushing whole screen
    }

    // MARK: - Header (no tabs)
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

                Text("Online • v3")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button {
                inputFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Messages
    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                            .padding(.horizontal, 14)
                    }
                    Color.clear.frame(height: 8).id("BOTTOM")
                }
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Composer (pinned, keyboard-safe)
    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Message VibeX AI…", text: $messageText, axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...5)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: .pink.opacity(0.35), radius: 10)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }

            // optional tiny helper row (no tabs)
            HStack {
                Text("V3 • Keyboard safe • No tabs")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Send
    private func send() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(.init(role: .user, text: trimmed))
        messageText = ""

        // Fake AI reply placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            messages.append(.init(role: .assistant, text: "Got it ✅ Let’s build: \(trimmed)"))
        }
    }
}

// MARK: - Models
struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

// MARK: - Bubble
private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant { bubbleLeading } else { bubbleTrailing }
        }
    }

    private var bubbleLeading: some View {
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            Spacer(minLength: 40)
        }
    }

    private var bubbleTrailing: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.text)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .shadow(color: .purple.opacity(0.25), radius: 10)
        }
    }
}

// MARK: - Background
private struct VibexChatBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.06, green: 0.05, blue: 0.14),
                Color(red: 0.03, green: 0.02, blue: 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RadialGradient(colors: [Color.purple.opacity(0.35), .clear],
                           center: .topLeading, startRadius: 20, endRadius: 420)
        )
        .overlay(
            RadialGradient(colors: [Color.blue.opacity(0.25), .clear],
                           center: .bottomTrailing, startRadius: 20, endRadius: 420)
        )
        .ignoresSafeArea()
    }
}

struct VibexAIChatV3_Preview: PreviewProvider {
    static var previews: some View {
        NavigationStack { VibexAIChatV3() }
    }
}
