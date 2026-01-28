import Foundation

public struct AIConversationRow: Codable, Sendable {
    public let id: String
    public let title: String
    public let messages: [VibeXChatMessage]
    public let updated_at: String

    public init(id: String, title: String, messages: [VibeXChatMessage], updated_at: String) {
        self.id = id
        self.title = title
        self.messages = messages
        self.updated_at = updated_at
    }
}
