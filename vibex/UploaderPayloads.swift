import Foundation

public struct UploaderVideoInsert: Encodable, Sendable {
    public let id: String
    public let user_id: String
    public let username: String
    public let caption: String?
    public let video_url: String
    public let thumbnail_url: String?

    public init(id: String, user_id: String, username: String, caption: String?, video_url: String, thumbnail_url: String? = nil) {
        self.id = id
        self.user_id = user_id
        self.username = username
        self.caption = caption
        self.video_url = video_url
        self.thumbnail_url = thumbnail_url
    }
}

// Provide a nonisolated `Encodable` implementation so encoding can occur
// from non-main-actor contexts (e.g., background tasks using Supabase client).
extension UploaderVideoInsert {
    private enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case username
        case caption
        case video_url
        case thumbnail_url
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(video_url, forKey: .video_url)
        try container.encodeIfPresent(thumbnail_url, forKey: .thumbnail_url)
    }
}
