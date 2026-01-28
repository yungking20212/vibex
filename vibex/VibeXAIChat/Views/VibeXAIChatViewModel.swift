#if false
import Foundation
import SwiftUI

@available(*, unavailable, message: "Use the public VibeXAIChatViewModel in VibeXAIChatViewModel.swift")
@MainActor
final class VibeXAIChatViewModel_Internal: ObservableObject {

    @Published var messages: [VibeXChatMessage] = []
    @Published var inputText: String = ""
    @Published var selectedTool: VibeXAITool = .chat
    @Published var isThinking: Bool = false
    @Published var errorBanner: String? = nil

    @Published var memory: AgentMemory = AgentMemory()
    @Published var attachments: [VibeXAttachment] = []
    @Published var lastAnimatedMessageID: String? = nil
    @Published var autoSendOnAppear: Bool = false

    private let client: VibeXAIClient
    private var lastUserText: String? = nil
    private var lastTool: VibeXAITool? = nil

    init(
        client: VibeXAIClient,
        initialTool: VibeXAITool = .chat,
        initialUserMessage: String = "",
        autoSendOnAppear: Bool = false
    ) {
        self.client = client
        self.selectedTool = initialTool
        self.autoSendOnAppear = autoSendOnAppear

        messages.append(
            .init(role: .assistant, text: "VibeX AI ready. Pick a tool and drop your idea.")
        )

        let trimmed = initialUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            inputText = trimmed
        }
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }

        // AI Clone requires video
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

        Task {
            do {
                let reply = try await client.send(
                    tool: selectedTool,
                    input: text,
                    history: messages,
                    memory: memory,
                    attachments: attachments
                )

                let assistant = VibeXChatMessage(role: .assistant, text: reply)
                messages.append(assistant)
                lastAnimatedMessageID = assistant.id
                attachments.removeAll()

            } catch {
                errorBanner = error.localizedDescription
            }
            isThinking = false
        }
    }

    func retryLast() {
        guard let lastUserText, let lastTool, !isThinking else { return }
        inputText = lastUserText
        selectedTool = lastTool
        send()
    }

    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }
}
#endif

