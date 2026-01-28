import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

// MARK: - Vibex AI Chat v3.5 (Glass, mic, tool animation, typing bubble, convo switcher)
struct VibexAIChatV3_5: View {
    @StateObject var viewModel: VibeXAIChatViewModel

    @FocusState private var inputFocused: Bool
    @Namespace private var toolNS

    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var pickedMediaItem: PhotosPickerItem? = nil

    @State private var showConversationsSheet = false
    @State private var showToolsSheet = false

    // Voice input (dictation-lite)
    @State private var isListening = false
    @State private var voiceText: String = ""
    private let speech = SimpleSpeechInput()

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
        .onAppear {
            viewModel.loadLocalConversations()
        }
        .sheet(isPresented: $showConversationsSheet) {
            ConversationSwitcherSheet(
                conversations: viewModel.conversations,
                currentId: viewModel.currentConversationId,
                onSelect: { id in
                    viewModel.switchToConversation(id: id)
                    showConversationsSheet = false
                },
                onNew: {
                    viewModel.createNewConversation(title: "Conversation")
                    showConversationsSheet = false
                }
            )
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showToolsSheet) {
            ToolPickerSheet(
                selected: viewModel.selectedTool,
                onSelect: { tool in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectedTool = tool
                    }
                    showToolsSheet = false
                }
            )
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [.purple, .pink, .blue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "sparkles").foregroundColor(.white))
                .shadow(color: .purple.opacity(0.35), radius: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("VibeX AI")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(viewModel.isThinking ? "Thinking…" : "Online • v3.5")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Tool chip (animated)
            Button {
                showToolsSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: toolIcon(viewModel.selectedTool))
                    Text(toolTitle(viewModel.selectedTool))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.92))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .overlay(alignment: .bottom) {
                    // matched geometry underline glow
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.purple, .pink, .blue],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3)
                        .matchedGeometryEffect(id: "toolUnderline", in: toolNS)
                        .padding(.horizontal, 10)
                        .offset(y: 10)
                        .opacity(0.9)
                }
            }
            .buttonStyle(.plain)

            Button {
                showConversationsSheet = true
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

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
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Message List + Typing bubble
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {

                    // Capabilities card pinned near top (what it can do NOW + Coming Soon)
                    CapabilitiesCard(
                        now: [
                            "AI Chat",
                            "AI Clone (with video attached)",
                            "AI Funny",
                            "AI Music Idea",
                            "AI Music Video (beta prompts)"
                        ],
                        soon: [
                            "AI Video → Movie",
                            "AI TV Show → Video Game",
                            "AI 6D / Cinematic Boost",
                            "AI Boost Post",
                            "More creator tools"
                        ]
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    ForEach(viewModel.messages, id: \.id) { msg in
                        ChatBubbleV3_5(message: msg)
                            .id(msg.id)
                            .padding(.horizontal, 14)
                            .transition(.opacity.combined(with: .move(edge: msg.role == .assistant ? .leading : .trailing)))
                    }

                    if viewModel.isThinking {
                        TypingIndicatorBubble()
                            .padding(.horizontal, 14)
                            .transition(.opacity)
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
            .onChange(of: viewModel.isThinking) { _, _ in
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

    // MARK: - Composer (mic + quick actions)
    private var composer: some View {
        VStack(spacing: 10) {
            if let error = viewModel.errorBanner {
                ErrorPillV3(text: error) { viewModel.retryLast() }
                    .padding(.horizontal, 14)
            }

            if !viewModel.attachments.isEmpty {
                AttachmentTray(
                    attachments: viewModel.attachments,
                    onRemove: { id in viewModel.removeAttachment(id) }
                )
                .padding(.horizontal, 14)
            }

            // Quick tool buttons (no tabs)
            quickActionsRow
                .padding(.horizontal, 14)

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

                // 🎤 Mic button
                Button {
                    micTapped()
                } label: {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: .purple.opacity(0.25), radius: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Send
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
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.08)), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                QuickChip(title: "Funny", icon: "face.smiling") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectedTool = .funny
                    }
                    viewModel.quickInsert("Make this funny in VibeX style.")
                }
                QuickChip(title: "Music idea", icon: "music.note") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectedTool = .musicIdea
                    }
                    viewModel.quickInsert("Give me 5 music video ideas for this song/vibe:")
                }
                QuickChip(title: "Music video", icon: "music.note.tv") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectedTool = .musicVideo
                    }
                    viewModel.quickInsert("Storyboard a music video: scenes, transitions, and shots.")
                }
                QuickChip(title: "Clone", icon: "person.crop.square") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.selectedTool = .clone
                    }
                    viewModel.quickInsert("Use my uploaded video to clone the vibe and write a script.")
                }
                QuickChip(title: "Coming soon", icon: "sparkles") {
                    inputFocused = false
                    showToolsSheet = true
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Mic tap
    private func micTapped() {
        if isListening {
            speech.stop()
            isListening = false
            if !voiceText.isEmpty {
                // Append voice to input
                if viewModel.inputText.isEmpty { viewModel.inputText = voiceText }
                else { viewModel.inputText += (viewModel.inputText.hasSuffix(" ") ? "" : " ") + voiceText }
                voiceText = ""
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }

        inputFocused = false
        isListening = true
        voiceText = ""

        speech.requestAuthorizationAndStart { partial in
            DispatchQueue.main.async {
                self.voiceText = partial
                // live preview in input (optional)
                if self.viewModel.inputText.isEmpty {
                    self.viewModel.inputText = partial
                } else {
                    // don’t constantly overwrite if user already typed
                }
            }
        } onStop: {
            DispatchQueue.main.async {
                self.isListening = false
            }
        }
    }

    // MARK: - Photos picker attach
    private func attachFromPhotosPicker(_ item: PhotosPickerItem) async {
        // Determine type from supported content types
        let types = item.supportedContentTypes
        let isImage = types.contains { $0.conforms(to: .image) }
        let isVideo = types.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }

        if isImage {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let uiImage = UIImage(data: data)
                let att = VibeXAttachment(kind: .image, filename: "photo.jpg", data: data, previewImage: uiImage)
                viewModel.attachments.append(att)
            }
        } else if isVideo {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let att = VibeXAttachment(kind: .video, filename: "video.mov", data: data, previewImage: nil)
                viewModel.attachments.append(att)
            }
        } else {
            // Fallback: try Data
            if let data = try? await item.loadTransferable(type: Data.self) {
                let att = VibeXAttachment(kind: .image, filename: "file.bin", data: data, previewImage: nil)
                viewModel.attachments.append(att)
            }
        }

        // clear selection
        await MainActor.run { pickedMediaItem = nil }
    }

    // MARK: - Background
    private var background: some View {
        LinearGradient(
            colors: [Color.black,
                     Color(red: 0.06, green: 0.05, blue: 0.14),
                     Color(red: 0.03, green: 0.02, blue: 0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(RadialGradient(colors: [Color.purple.opacity(0.30), .clear],
                                center: .topLeading, startRadius: 20, endRadius: 420))
        .overlay(RadialGradient(colors: [Color.blue.opacity(0.22), .clear],
                                center: .bottomTrailing, startRadius: 20, endRadius: 420))
        .ignoresSafeArea()
    }

    private func toolTitle(_ tool: VibeXAITool) -> String {
        switch tool {
        case .chat: return "Chat"
        case .clone: return "Clone"
        case .funny: return "Funny"
        case .musicIdea: return "Music Idea"
        case .musicVideo: return "Music Video"
        default: return "Tool"
        }
    }

    private func toolIcon(_ tool: VibeXAITool) -> String {
        switch tool {
        case .chat: return "sparkles"
        case .clone: return "person.crop.square.filled.and.at.rectangle"
        case .funny: return "face.smiling.fill"
        case .musicIdea: return "music.note"
        case .musicVideo: return "music.note.tv.fill"
        default: return "wand.and.stars"
        }
    }
}

// MARK: - Tool Picker Sheet
private struct ToolPickerSheet: View {
    let selected: VibeXAITool
    let onSelect: (VibeXAITool) -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Tools")
                    .font(.title2.weight(.heavy))
                    .foregroundColor(.white)
                    .padding(.top, 18)

                VStack(spacing: 10) {
                    ToolRow(title: "Chat", subtitle: "General assistant", icon: "sparkles", active: selected == .chat) { onSelect(.chat) }
                    ToolRow(title: "Clone", subtitle: "Use your video attachment", icon: "person.crop.square.filled.and.at.rectangle", active: selected == .clone) { onSelect(.clone) }
                    ToolRow(title: "Funny", subtitle: "Make it hilarious", icon: "face.smiling.fill", active: selected == .funny) { onSelect(.funny) }
                    ToolRow(title: "Music Idea", subtitle: "Hooks, themes, captions", icon: "music.note", active: selected == .musicIdea) { onSelect(.musicIdea) }
                    ToolRow(title: "Music Video", subtitle: "Storyboard + shots", icon: "music.note.tv.fill", active: selected == .musicVideo) { onSelect(.musicVideo) }

                    // Coming soon rows
                    ComingSoonRow(title: "Video → Movie", icon: "film")
                    ComingSoonRow(title: "TV Show → Video Game", icon: "gamecontroller")
                    ComingSoonRow(title: "AI Boost Post", icon: "bolt.fill")
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }
}

private struct ToolRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                        .opacity(active ? 1 : 0.65)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).foregroundColor(.white).font(.headline)
                    Text(subtitle).foregroundColor(.white.opacity(0.65)).font(.caption)
                }

                Spacer()

                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ComingSoonRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 18, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundColor(.white).font(.headline)
                Text("Coming soon").foregroundColor(.white.opacity(0.55)).font(.caption)
            }

            Spacer()

            Text("Soon")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Conversation Switcher
private struct ConversationSwitcherSheet: View {
    let conversations: [VibeXAIChatViewModel.AIConversation]
    let currentId: String?
    let onSelect: (String) -> Void
    let onNew: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("Conversations")
                        .font(.title2.weight(.heavy))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        onNew()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(conversations) { c in
                            Button {
                                onSelect(c.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(c.title.isEmpty ? "Conversation" : c.title)
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .lineLimit(1)

                                        Text("\(c.messages.count) messages")
                                            .foregroundColor(.white.opacity(0.6))
                                            .font(.caption)
                                    }
                                    Spacer()
                                    if currentId == c.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                                    } else {
                                        Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }

                        if conversations.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.85))
                                Text("No conversations yet")
                                    .foregroundColor(.white.opacity(0.85))
                                Button("Start one") { onNew() }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Capabilities Card (NOW vs SOON)
private struct CapabilitiesCard: View {
    let now: [String]
    let soon: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VibeX AI")
                .font(.title3.weight(.heavy))
                .foregroundColor(.white)

            HStack(spacing: 10) {
                PillTag(text: "What it can do now", icon: "checkmark.seal.fill")
                PillTag(text: "Coming soon", icon: "sparkles")
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Now")
                        .font(.headline)
                        .foregroundColor(.white)
                    ForEach(now, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .leading, endPoint: .trailing))
                            Text(item).foregroundColor(.white.opacity(0.9)).font(.subheadline)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Soon")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    ForEach(soon, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.white.opacity(0.7))
                            Text(item).foregroundColor(.white.opacity(0.75)).font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .purple.opacity(0.18), radius: 16)
    }
}

private struct PillTag: View {
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white.opacity(0.92))
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - Quick Chip
private struct QuickChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
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

// MARK: - Typing Indicator Bubble
private struct TypingIndicatorBubble: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(Color.white.opacity(phase % 3 == idx ? 0.95 : 0.28))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase % 3 == idx ? 1.08 : 0.92)
                        .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(idx) * 0.12), value: phase)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))

            Spacer()
        }
        .onAppear {
            Task {
                while true {
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    phase += 1
                }
            }
        }
    }
}

// MARK: - Error pill
private struct ErrorPillV3: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LinearGradient(colors: [.purple, .pink, .blue], startPoint: .leading, endPoint: .trailing))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            Spacer()
            Button("Retry") { retry() }
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
}

// MARK: - Bubble
private struct ChatBubbleV3_5: View {
    let message: VibeXChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                assistant
            } else {
                user
            }
        }
    }

    private var assistant: some View {
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
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))

            Spacer(minLength: 40)
        }
    }

    private var user: some View {
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

// MARK: - SimpleSpeechInput (dictation-lite)
// NOTE: This is a lightweight placeholder for “voice to text” UX.
// For full speech recognition, add Speech framework + SFSpeechRecognizer.
private struct AttachmentTray: View {
    let attachments: [VibeXAttachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments, id: \.id) { att in
                    AttachmentChip(att: att) { onRemove(att.id) }
                }
            }
            .padding(.vertical, 4)
        }
    }
}



final class SimpleSpeechInput {
    private let audio = AVAudioSession.sharedInstance()

    func requestAuthorizationAndStart(onPartial: @escaping (String) -> Void, onStop: @escaping () -> Void) {
        // Minimal UX mock: it “listens” and drops placeholder text quickly.
        // Replace with SFSpeechRecognizer for real transcription.
        Task {
            try? audio.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
            try? audio.setActive(true)

            // Simulated partials
            let parts = ["Yo", "Yo VibeX", "Yo VibeX AI", "Yo VibeX AI make a caption for my video"]
            for p in parts {
                try? await Task.sleep(nanoseconds: 220_000_000)
                await MainActor.run { onPartial(p) }
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            try? audio.setActive(false)
            await MainActor.run { onStop() }
        }
    }

    func stop() {
        try? audio.setActive(false)
    }
}
