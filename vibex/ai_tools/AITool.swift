import Foundation

/// Shared AI tool enumeration used across the app.
/// Add or remove cases here as new tools are implemented.
public enum AITool: String, CaseIterable, Hashable, Identifiable {
    case aiFunny
    case chat
    case image
    case code
    case sample

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .aiFunny: return "Funny AI"
        case .chat: return "Chat"
        case .image: return "Image"
        case .code: return "Code"
        case .sample: return "Sample"
        }
    }
}
