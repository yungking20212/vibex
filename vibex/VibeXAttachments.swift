import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Agent Memory (persisted)
public struct AgentMemory: Codable, Hashable {
    var savedStyle: String = "Clean & Next-Gen"
    var myVoice: String = "Confident, short, punchy"
    var brandTone: String = "Premium, futuristic, viral"
}

// MARK: - Attachments
public enum VibeXAttachmentKind: String, Codable {
    case image
    case video
}

public struct VibeXAttachment: Identifiable, Hashable {
    public let id = UUID()
    let kind: VibeXAttachmentKind
    let filename: String
    let data: Data               // bytes (base64 sent)
    let previewImage: UIImage?   // for UI only
}

// Encoded payload attachment (sent to vibex-ai-chat)
public struct VibeXAttachmentPayload: Encodable {
    let type: String   // "video" or "image"
    let url: String
}
