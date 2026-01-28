import Foundation
import SwiftUI

// Tool set for VibeX AI
public enum VibeXAITool: String, CaseIterable, Hashable {
    case chat = "Chat"
    case caption = "AI Caption"
    case hashtags = "Hashtags"
    case story = "AI Story"
    case clone = "AI Clone"
    case funny = "AI Funny"
    case musicIdea = "AI Music Idea"
    case musicVideo = "AI Music Video"
    case boost = "Boost Post"

    public var icon: String {
        switch self {
        case .chat: return "sparkles"
        case .caption: return "captions.bubble.fill"
        case .hashtags: return "number"
        case .story: return "book.fill"
        case .clone: return "person.crop.square.filled.and.at.rectangle"
        case .funny: return "face.smiling.fill"
        case .musicIdea: return "music.note"
        case .musicVideo: return "music.note.tv.fill"
        case .boost: return "bolt.fill"
        }
    }

    public var shortHint: String {
        switch self {
        case .chat: return "Ask anything"
        case .caption: return "Generate captions"
        case .hashtags: return "Generate tags"
        case .story: return "Write a story"
        case .clone: return "Clone style"
        case .funny: return "Make it funny"
        case .musicIdea: return "Music idea prompts"
        case .musicVideo: return "Music video ideas"
        case .boost: return "Boost engagement"
        }
    }
}

public struct VibeXChatMessage: Identifiable, Hashable, Codable, Sendable {
    public enum Role: String, Codable { case user, assistant, system }
    public let id: String
    public let role: Role
    public let text: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString, role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

// Flexible response decoding used for many function shapes
public struct VibeXAIResponse: Decodable {
    public let reply: String?
    public let message: String?
    public let content: String?
    public let output: String?
    public let text: String?
    public let data: NestedData?

    public struct NestedData: Decodable {
        public let reply: String?
        public let message: String?
        public let content: String?
        public let output: String?
        public let text: String?
    }

    public var bestText: String? {
        if let value = reply ?? message ?? content ?? output ?? text {
            return value
        }
        if let nested = data {
            if let value = nested.reply ?? nested.message ?? nested.content ?? nested.output ?? nested.text {
                return value
            }
        }
        return nil
    }
}
