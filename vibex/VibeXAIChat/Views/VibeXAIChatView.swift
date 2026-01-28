import SwiftUI
import Foundation
import UIKit
import PhotosUI
import Combine

typealias ChatVM = VibeXAIChatViewModel

// MARK: - View
struct VibeXAIChatView: View {
    @StateObject private var vm: ChatVM
    @Environment(\.dismiss) private var dismiss

    init(
        initialTool: VibeXAITool = .chat,
        initialUserMessage: String = "",
        autoSendOnAppear: Bool = false,
        functionURL: URL = URL(string: "https://jnkzbfqrwkgfiyxvwrug.supabase.co/functions/v1/vibex-ai-chat")!,
        publishableKey: String = "sb_publishable_adOiMlBxXb6tNIUIxa4lTQ_suJw_Jdz"
    ) {
        let client = VibeXAIClient(functionURL: functionURL, publishableKey: publishableKey)
        _vm = StateObject(wrappedValue: ChatVM(client: client, initialTool: initialTool, initialUserMessage: initialUserMessage, autoSendOnAppear: autoSendOnAppear))
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 10) {
                topBar
                toolRail

                // Make chat list expand to fill available space so composer stays anchored
                chatList
                    .frame(maxHeight: .infinity)

                // Show memory chips and attachments adaptively. If there are attachments,
                // display them side-by-side to save vertical space; otherwise show memory only.
                Group {
                    if !vm.attachments.isEmpty {
                        HStack(spacing: 10) {
                            AgentMemoryChips(memory: $vm.memory, onEdit: { showingMemoryEditor = true })
                            AttachmentsRow(attachments: $vm.attachments) { id in vm.removeAttachment(id) }
                        }
                        .padding(.horizontal, 12)
                    } else {
                        AgentMemoryChips(memory: $vm.memory, onEdit: { showingMemoryEditor = true })
                            .padding(.horizontal, 12)
                    }
                }

                composer
            }
            .padding(.top, 6)
            .padding(.bottom, CGFloat(8) + keyboard.height)
        }
        .navigationBarHidden(true)
        .onAppear {
            if vm.autoSendOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    vm.autoSendOnAppear = false
                    vm.send()
                }
            }
        }
        .sheet(isPresented: $showingMemoryEditor) {
            MemoryEditor(memory: $vm.memory)
        }
// keyboard handling is provided by `KeyboardObserver` (iOS-only)
    }

    @State private var showingMemoryEditor = false

#if os(iOS)
    @State private var isKeyboardVisible: Bool = false
#endif

    @StateObject private var keyboard = KeyboardObserver()

    // MARK: - UI Pieces
    private var background: some View {
        ZStack {
            // Neon gradient sweep: Purple → Pink → Blue
            LinearGradient(
                colors: [
                    Color.vbPurple.opacity(0.28),
                    Color.vbPink.opacity(0.28),
                    Color.vbBlue.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Soft radial glow near the top
            RadialGradient(
                colors: [Color.white.opacity(0.12), .clear],
                center: .top,
                startRadius: 12,
                endRadius: 460
            )
            .ignoresSafeArea()

            // Subtle vignette to frame content
            LinearGradient(
                colors: [Color.black.opacity(0.10), .clear, Color.black.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            #endif

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: vm.selectedTool.icon)
                    Text("VibeX AI — Next‑Gen")
                        .font(.headline).bold()
                        .foregroundStyle(
                            LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color.vbBlue.opacity(0.25), radius: 6, x: 0, y: 2)
                }
                Text(vm.selectedTool.shortHint)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Menu {
                Button("New Chat") { vm.newChat() }
                Button("Clear Chat") { vm.clearChat() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.headline)
            }

            if vm.isThinking { ThinkingPill() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .padding(.top, 2)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var toolRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(VibeXAITool.allCases, id: \.self) { tool in
                    ToolChip(title: tool.rawValue, icon: tool.icon, isSelected: tool == vm.selectedTool)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { vm.selectedTool = tool }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                }

                NavigationLink(destination: AIGameView()) {
                    ToolChip(title: "AI Game", icon: "gamecontroller.fill", isSelected: false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: {
                    #if os(macOS)
                    12
                    #else
                    10
                    #endif
                }()) {
                    if let err = vm.errorBanner {
                        ErrorBanner(text: err, retry: { vm.retryLast() })
                            .padding(.horizontal, 12)
                    }

                    ForEach(vm.messages) { msg in
                        VStack(alignment: .leading, spacing: 8) {
                            MessageRow(message: msg, lastAnimatedID: vm.lastAnimatedMessageID)
                                .id(msg.id)
                                .padding(.horizontal, 12)
                            if msg.role == .assistant {
                                HStack(spacing: 10) {
                                    Button { vm.rateMessage(msg.id, true) } label: { Image(systemName: "hand.thumbsup") }
                                    Button { vm.rateMessage(msg.id, false) } label: { Image(systemName: "hand.thumbsdown") }
                                    Spacer()
                                    Menu {
                                        Button("Copy") { vm.copyMessage(msg.id) }
                                        Button("Export as Markdown") { vm.exportMessage(msg.id, "markdown") }
                                        Button("Share…") { vm.shareMessage(msg.id) }
                                    } label: { Image(systemName: "ellipsis.circle") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.9))
                                .padding(.horizontal, 12)
                            }
                        }
                    }

                    if vm.isThinking {
                        TypingBubble()
                            .padding(.horizontal, 12)
                            .id("typing")
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, {
                    #if os(macOS)
                    12
                    #else
                    10
                    #endif
                }())
            }
            .overlay(alignment: .bottomTrailing) {
                if vm.hasUnreadBelow {
                    Button(action: { vm.scrollToBottom() }) {
                        Label("New messages", systemImage: "arrow.down")
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                }
            }
            .onChange(of: vm.messages) { oldMessages, newMessages in
                withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo("bottom", anchor: .bottom) }
                if let last = newMessages.last, last.role == .assistant {
                    vm.lastAnimatedMessageID = last.id
                    vm.markUnreadIfNotAtBottom()
                }
            }
            .onChange(of: vm.isThinking) {
                withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            quickActions

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if vm.inputText.isEmpty {
                        Text("Message \(vm.selectedTool.rawValue)…")
                            .foregroundStyle(.secondary.opacity(0.9))
                            .padding(.leading, 14)
                    }
                    TextField("", text: $vm.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .onSubmit {
                            if vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
                                vm.handleSlashCommand(vm.inputText)
                            } else {
                                vm.send()
                            }
                        }
#if os(macOS)
                        .onExitCommand(perform: { vm.inputText = "" })
#endif
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

                Group {
                    if vm.isThinking {
                        Button { vm.cancelCurrentRequest() } label: {
                            Image(systemName: "stop.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red.opacity(0.9), in: Circle())
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .disabled(!vm.isThinking)
                        .opacity(vm.isThinking ? 1.0 : 0.6)
                    } else {
                        Button {
                            if vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
                                vm.handleSlashCommand(vm.inputText)
                            } else {
                                vm.send()
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.90)],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    in: Circle()
                                )
                                .overlay(
                                    Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        .keyboardShortcut(.return, modifiers: [.command])

                        Button("Clear Chat") { vm.clearChat() }
                            .keyboardShortcut("k", modifiers: [.command])
                            .hidden()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 12)

#if os(iOS)
            if !isKeyboardVisible {
                HStack {
                    Toggle(isOn: Binding(get: { vm.useMemoryForNextMessage }, set: { vm.setUseMemoryForNextMessage($0) })) { Text("Use memory") }
                    Spacer()
                    Menu("Tone") {
                        Button("Professional") { vm.applyTone("professional") }
                        Button("Friendly") { vm.applyTone("friendly") }
                        Button("TikTok") { vm.applyTone("tiktok") }
                        Button("Academic") { vm.applyTone("academic") }
                    }
                    Menu("Persona") {
                        Button("Default") { vm.applyPersona("default") }
                        Button("Coach") { vm.applyPersona("coach") }
                        Button("Marketer") { vm.applyPersona("marketer") }
                        Button("Engineer") { vm.applyPersona("engineer") }
                    }
                }
                .padding(.horizontal, 12)
            }
#else
            HStack {
                Toggle(isOn: Binding(get: { vm.useMemoryForNextMessage }, set: { vm.setUseMemoryForNextMessage($0) })) { Text("Use memory") }
                Spacer()
                Menu("Tone") {
                    Button("Professional") { vm.applyTone("professional") }
                    Button("Friendly") { vm.applyTone("friendly") }
                    Button("TikTok") { vm.applyTone("tiktok") }
                    Button("Academic") { vm.applyTone("academic") }
                }
                Menu("Persona") {
                    Button("Default") { vm.applyPersona("default") }
                    Button("Coach") { vm.applyPersona("coach") }
                    Button("Marketer") { vm.applyPersona("marketer") }
                    Button("Engineer") { vm.applyPersona("engineer") }
                }
            }
            .padding(.horizontal, 12)
#endif
        }
        .padding(.top, 4)
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickPill(title: "Make it shorter") { vm.quickInsert("Make it shorter.") }
                QuickPill(title: "Make it better") { vm.quickInsert("Make it better and more next-gen.") }
                QuickPill(title: "Add emojis") { vm.quickInsert("Add emojis.") }
                QuickPill(title: "Give 10 options") { vm.quickInsert("Give me 10 options.") }
                QuickPill(title: "TikTok style") { vm.quickInsert("TikTok style tone.") }
            }
            .padding(.horizontal, 12)
        }
    }


// Components are implemented centrally in VibeXAIComponents.swift

// Use shared UI components from VibeXAIChat/Components/VibeXAIComponents.swift
}

 // MARK: - Preview
#Preview {
    NavigationStack { VibeXAIChatView(initialTool: .chat) }
}

