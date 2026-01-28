import Foundation
import SwiftUI
import Combine
import UIKit
import Supabase

nonisolated struct MessageDTO: Codable, Hashable, Sendable {
    let id: String
    let role: String
    let text: String
    let createdAt: Date?

    init(from message: VibeXChatMessage) {
        self.id = message.id
        self.role = message.role.rawValue
        self.text = message.text
        // If VibeXChatMessage has a timestamp, map it; otherwise keep nil
        if let created = (message as AnyObject).value(forKey: "createdAt") as? Date {
            self.createdAt = created
        } else {
            self.createdAt = nil
        }
    }
}

nonisolated struct SupabaseConversationPayload: Codable, Sendable {
    let id: String
    let title: String
    let messages: [MessageDTO]
    let updated_at: String
}

@MainActor
public final class VibeXAIChatViewModel: ObservableObject {

    @Published public var messages: [VibeXChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var selectedTool: VibeXAITool = .chat
    @Published public var isThinking: Bool = false
    @Published public var errorBanner: String? = nil
    @Published public var memory: AgentMemory = AgentMemory()
    @Published public var attachments: [VibeXAttachment] = []
    @Published public var lastAnimatedMessageID: String? = nil
    @Published public var autoSendOnAppear: Bool = false
    @Published public var conversations: [AIConversation] = []
    @Published public var currentConversationId: String? = nil
    @Published public var hasUnreadBelow: Bool = false
    @Published public var useMemoryForNextMessage: Bool = true

    private let client: VibeXAIClient
    private var lastUserText: String? = nil
    private var lastTool: VibeXAITool? = nil
    private var activeTask: Task<Void, Never>? = nil

    private func systemPrompt(for tool: VibeXAITool) -> String {
        switch tool {
        case .chat:
            return "You are VibeX AI — Next‑Gen. Be concise, helpful, and on‑brand."
        case .clone:
            return "VibeX AI Clone mode: analyze the provided video and generate an on‑brand voice."
        default:
            return "VibeX AI — Next‑Gen assistant."
        }
    }

    public init(
        client: VibeXAIClient,
        initialTool: VibeXAITool = .chat,
        initialUserMessage: String = "",
        autoSendOnAppear: Bool = false
    ) {
        self.client = client
        self.selectedTool = initialTool
        self.autoSendOnAppear = autoSendOnAppear

        // Initialize @Published backing storage directly to avoid touching
        // `objectWillChange` before the instance is fully initialized.
        let starter = VibeXChatMessage(role: .assistant, text: "VibeX AI ready. Pick a tool and drop your idea.")
        self._messages = Published(initialValue: [starter])

        let msg = initialUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        self._inputText = Published(initialValue: msg.isEmpty ? "" : msg)
    }

    public func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
            // Moderation check
            if !moderateIfNeeded(text) {
                errorBanner = "Message blocked by moderation"
                return
            }

        if selectedTool == .clone {
            let hasVideo = attachments.contains { $0.kind == .video }
            if !hasVideo {
                errorBanner = "AI Clone requires a video upload."
                return
            }
        }

        lastUserText = text
        lastTool = selectedTool

        messages.append(.init(role: .user, text: text))
        inputText = ""
        isThinking = true
        errorBanner = nil

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Cancel any previous task
        activeTask?.cancel()

        activeTask = Task { [weak self] in
            guard let self = self else { return }
            defer { Task { @MainActor in self.isThinking = false; self.activeTask = nil } }

            // Simple retry with backoff: up to 2 retries (3 total attempts)
            let maxAttempts = 3
            var attempt = 0
            while attempt < maxAttempts {
                attempt += 1
                do {
                    let prompt = self.systemPrompt(for: self.selectedTool)
                    let memoryToUse = self.useMemoryForNextMessage ? self.memory : AgentMemory()


                    // Use streaming API when available: append an empty assistant message and update progressively
                    let stream = try await self.client.sendStream(
                        tool: self.selectedTool,
                        input: text,
                        history: self.messages,
                        memory: memoryToUse,
                        attachments: self.attachments,
                        systemPrompt: prompt
                    )

                    // Create assistant placeholder
                    let assistant = VibeXChatMessage(role: .assistant, text: "")
                    await MainActor.run {
                        self.messages.append(assistant)
                        self.lastAnimatedMessageID = assistant.id
                    }

                    // Consume stream and append to the assistant message progressively
                    do {
                        for try await chunk in stream {
                            await MainActor.run {
                                if let idx = self.messages.firstIndex(where: { $0.id == assistant.id }) {
                                    let old = self.messages[idx]
                                    let updated = VibeXChatMessage(id: old.id, role: old.role, text: old.text + chunk, createdAt: old.createdAt)
                                    self.messages[idx] = updated
                                }
                            }
                        }
                        await MainActor.run {
                            self.attachments.removeAll()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } catch {
                        await MainActor.run {
                            self.errorBanner = "Streaming error: \(error.localizedDescription)"
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }

                    // Persist conversation locally and attempt sync to Supabase
                    await saveCurrentConversation()
                    Task { await syncCurrentConversationToSupabase() }
                    return
                } catch is CancellationError {
                    await MainActor.run {
                        self.errorBanner = "Request cancelled."
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                    return
                } catch {
                    if attempt >= maxAttempts {
                        await MainActor.run {
                            self.errorBanner = error.localizedDescription
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                        return
                    } else {
                        // Backoff: 0.6s, 1.2s
                        let delay = UInt64(600_000_000 * attempt)
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            }
        }
    }

    public func retryLast() {
        guard let lastUserText, let lastTool, !isThinking else { return }
        inputText = lastUserText
        selectedTool = lastTool
        send()
    }

    public func clearChat() {
        messages.removeAll()
        errorBanner = nil
    }

    public func newChat() {
        clearChat()
        messages.append(.init(role: .assistant, text: "VibeX AI ready. Pick a tool and drop your idea."))
    }

    public func cancelCurrentRequest() {
        activeTask?.cancel()
        activeTask = nil
        isThinking = false
    }

    public func handleSlashCommand(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { send(); return }
        let command = String(trimmed.dropFirst()).lowercased()
        switch command {
        case "summarize": inputText = "Summarize the above conversation."; send()
        case "shorten": inputText = "Make it shorter."; send()
        case "emojis": inputText = "Add emojis."; send()
        case "tiktok": inputText = "Rewrite in TikTok style."; send()
        case "outline": inputText = "Create an outline from the above."; send()
        default:
            inputText = String(trimmed.dropFirst()); send()
        }
    }

    public func rateMessage(_ id: String, _ up: Bool) {
        // TODO: hook analytics/feedback pipeline
        print("[Feedback] message=\(id) rating=\(up ? "up" : "down")")
    }

    public func copyMessage(_ id: String) {
        guard let msg = messages.first(where: { $0.id == id }) else { return }
        UIPasteboard.general.string = msg.text
    }

    public func exportMessage(_ id: String, _ format: String) {
        // Stub: implement export pipeline (Markdown, etc.)
        print("[Export] message=\(id) format=\(format)")
    }

    public func shareMessage(_ id: String) {
        // Stub: delegate to a share sheet from the View if needed
        print("[Share] message=\(id)")
    }

    public func continueLastResponse() {
        // Stub: ask the model to continue
        inputText = "Continue."
        send()
    }

    public func copyLastResponse() {
        if let last = messages.last(where: { $0.role == .assistant }) {
            UIPasteboard.general.string = last.text
        }
    }

    public func exportConversation() {
        // Stub: export entire conversation as Markdown
        let md = messages.map { "**\($0.role.rawValue.capitalized):** \($0.text)" }.joined(separator: "\n\n")
        print("[Export] conversation markdown size=\(md.count)")
    }

    public func setUseMemoryForNextMessage(_ use: Bool) {
        useMemoryForNextMessage = use
    }

    public func applyTone(_ name: String) {
        // Stub: adjust memory or system prompt hints
        print("[Tone] \(name)")
    }

    public func applyPersona(_ name: String) {
        // Stub: adjust persona hints
        print("[Persona] \(name)")
    }

    public func scrollToBottom() {
        hasUnreadBelow = false
    }

    public func markUnreadIfNotAtBottom() {
        // Simple heuristic: whenever messages change while thinking, mark unread
        if isThinking { hasUnreadBelow = true }
    }

    public func quickInsert(_ template: String) {
        if inputText.isEmpty {
            inputText = template
        } else {
            inputText += (inputText.hasSuffix(" ") ? "" : " ") + template
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    public func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }
    
    public func moderateIfNeeded(_ text: String) -> Bool {
        // Simple client-side moderation: block if contains any disallowed tokens.
        // In future this can call an external moderation API.
        let blockedTokens = ["sex", "rape", "terror", "bomb", "drugs"]
        let lowered = text.lowercased()
        for t in blockedTokens where lowered.contains(t) {
            return false
        }
        return true
    }

    // MARK: - Conversation persistence
    public struct AIConversation: Codable, Identifiable, Hashable {
        public let id: String
        public var title: String
        public var messages: [VibeXChatMessage]
        public var createdAt: Date
        public var updatedAt: Date
    }

    private let conversationsKey = "vibex_ai_conversations"

    public func loadLocalConversations() {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey) else { return }
        if let decoded = try? JSONDecoder().decode([AIConversation].self, from: data) {
            conversations = decoded
            currentConversationId = conversations.first?.id
        }
    }

    public func saveCurrentConversation() async {
        let convId = currentConversationId ?? UUID().uuidString
        let title = messages.first?.text.prefix(60).description ?? "Conversation"
        let conv = AIConversation(id: convId, title: String(title), messages: messages, createdAt: Date(), updatedAt: Date())

        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        } else {
            conversations.insert(conv, at: 0)
            currentConversationId = conv.id
        }

        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: conversationsKey)
        }
    }

    public func switchToConversation(id: String) {
        guard let conv = conversations.first(where: { $0.id == id }) else { return }
        messages = conv.messages
        currentConversationId = id
    }

    public func createNewConversation(title: String = "Conversation") {
        messages.removeAll()
        let conv = AIConversation(id: UUID().uuidString, title: title, messages: [], createdAt: Date(), updatedAt: Date())
        conversations.insert(conv, at: 0)
        currentConversationId = conv.id
        if let data = try? JSONEncoder().encode(conversations) { UserDefaults.standard.set(data, forKey: conversationsKey) }
    }
}

// AIConversationRow moved to top-level model file to avoid MainActor isolation

@MainActor
extension VibeXAIChatViewModel {
    // Best-effort sync to Supabase: insert or update a JSON column `messages` in table `ai_conversations`.
    public func syncCurrentConversationToSupabase() async {
        // Snapshot needed data on the main actor
        guard let id = self.currentConversationId else { return }
        guard let conv = self.conversations.first(where: { $0.id == id }) else { return }

        // Prepare nonisolated snapshot to cross actor boundary safely
        let snapshotId = conv.id
        let snapshotTitle = conv.title
        let snapshotMessages = conv.messages
        let snapshotUpdatedAt = conv.updatedAt

        let client = SupabaseConfig.shared.client
        let updatedAtString = ISO8601DateFormatter().string(from: snapshotUpdatedAt)

        let dtoMessages = snapshotMessages.map { MessageDTO(from: $0) }
        let payload = SupabaseConversationPayload(
            id: snapshotId,
            title: snapshotTitle,
            messages: dtoMessages,
            updated_at: updatedAtString
        )

        do {
            _ = try await client.database
                .from("ai_conversations")
                .upsert(payload)
                .execute()
        } catch {
            // Best-effort: ignore sync errors for now
        }
    }
}
