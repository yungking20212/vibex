//
//  Models.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation

// MARK: - User Model

struct User: Identifiable, Sendable {
    let id: String
    var username: String
    var email: String
    var avatarURL: String?
    var bio: String?
    var followersCount: Int
    var followingCount: Int
    var likesCount: Int
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case avatarURL = "avatar_url"
        case bio
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case likesCount = "likes_count"
        case createdAt = "created_at"
    }
}

// MARK: - Profile Model

struct Profile: Identifiable, Sendable {
    let id: UUID
    var username: String?
    var display_name: String?
    var bio: String?
    var avatar_url: String?
    var created_at: Date?
    var updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case display_name
        case bio
        case avatar_url
        case created_at
        case updated_at
    }
    
    // Explicit nonisolated initializer
    nonisolated init(
        id: UUID,
        username: String? = nil,
        display_name: String? = nil,
        bio: String? = nil,
        avatar_url: String? = nil,
        created_at: Date? = nil,
        updated_at: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.display_name = display_name
        self.bio = bio
        self.avatar_url = avatar_url
        self.created_at = created_at
        self.updated_at = updated_at
    }
}

// Make `Profile` Codable methods nonisolated so encoding/decoding can occur
// from non-main-actor contexts (e.g., Supabase client calls).
extension Profile: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
        self.avatar_url = try container.decodeIfPresent(String.self, forKey: .avatar_url)
        self.created_at = try container.decodeIfPresent(Date.self, forKey: .created_at)
        self.updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}

extension Profile: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(display_name, forKey: .display_name)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }
}


// Make Codable conformances nonisolated so they can be used from non-main-actor contexts
extension User: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.username = try container.decode(String.self, forKey: .username)
        self.email = try container.decode(String.self, forKey: .email)
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
        self.followersCount = try container.decode(Int.self, forKey: .followersCount)
        self.followingCount = try container.decode(Int.self, forKey: .followingCount)
        self.likesCount = try container.decode(Int.self, forKey: .likesCount)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension User: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encode(followersCount, forKey: .followersCount)
        try container.encode(followingCount, forKey: .followingCount)
        try container.encode(likesCount, forKey: .likesCount)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension VideoPost: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.username = try container.decode(String.self, forKey: .username)
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
        self.videoURL = try container.decode(String.self, forKey: .videoURL)
        self.thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        self.likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        self.comments = try container.decodeIfPresent(Int.self, forKey: .comments) ?? 0
        self.shares = try container.decodeIfPresent(Int.self, forKey: .shares) ?? 0
        self.views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

extension VideoPost: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(videoURL, forKey: .videoURL)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(likes, forKey: .likes)
        try container.encode(comments, forKey: .comments)
        try container.encode(shares, forKey: .shares)
        try container.encode(views, forKey: .views)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension Comment: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.videoId = try container.decode(String.self, forKey: .videoId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.username = try container.decode(String.self, forKey: .username)
        self.text = try container.decode(String.self, forKey: .text)
        self.likes = try container.decode(Int.self, forKey: .likes)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension Comment: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(userId, forKey: .userId)
        try container.encode(username, forKey: .username)
        try container.encode(text, forKey: .text)
        try container.encode(likes, forKey: .likes)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Video Post Model

struct VideoPost: Identifiable, Sendable {
    let id: String
    var userId: String
    var username: String
    var caption: String?
    var videoURL: String
    var thumbnailURL: String?
    var likes: Int
    var comments: Int
    var shares: Int
    var views: Int
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case caption
        case videoURL = "video_url"
        case thumbnailURL = "thumbnail_url"
        case likes
        case comments
        case shares
        case views
        case createdAt = "created_at"
    }
}

extension Follow: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.followerId = try container.decode(String.self, forKey: .followerId)
        self.followingId = try container.decode(String.self, forKey: .followingId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension Follow: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(followerId, forKey: .followerId)
        try container.encode(followingId, forKey: .followingId)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Comment Model

struct Comment: Identifiable, Sendable {
    let id: String
    var videoId: String
    var userId: String
    var username: String
    var text: String
    var likes: Int
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case videoId = "video_id"
        case userId = "user_id"
        case username
        case text
        case likes
        case createdAt = "created_at"
    }
}

// MARK: - Like Model

struct Like: Identifiable, Sendable {
    let id: String
    var userId: String
    var videoId: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case videoId = "video_id"
        case createdAt = "created_at"
    }
}

// Make `Decodable` and `Encodable` conformances nonisolated so they can be used from non-main-actor contexts
extension Like: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.videoId = try container.decode(String.self, forKey: .videoId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension Like: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Follow Model

struct Follow: Identifiable, Sendable {
    let id: String
    var followerId: String
    var followingId: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - User Stats View Model

struct UserStats: Identifiable, Sendable {
    let id: String
    var userId: String
    var username: String?
    var avatarURL: String?
    var bio: String?
    var followersCount: Int
    var followingCount: Int
    var likesCount: Int
    var totalVideoLikes: Int
    var totalVideoViews: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case avatarURL = "avatar_url"
        case bio
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case likesCount = "likes_count"
        case totalVideoLikes = "total_video_likes"
        case totalVideoViews = "total_video_views"
    }
}

extension UserStats: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.id = self.userId
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
        self.followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        self.followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        self.likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        self.totalVideoLikes = try container.decodeIfPresent(Int.self, forKey: .totalVideoLikes) ?? 0
        self.totalVideoViews = try container.decodeIfPresent(Int.self, forKey: .totalVideoViews) ?? 0
    }
}

