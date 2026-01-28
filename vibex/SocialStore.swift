//
//  SocialStore.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import Supabase
import Combine

// MARK: - Like Model

struct VideoLike: Identifiable, Sendable {
    let id: UUID
    let user_id: UUID
    let video_id: UUID
    let created_at: Date
}

// MARK: - Comment Model

struct VideoComment: Identifiable, Sendable {
    let id: UUID
    let video_id: UUID
    let user_id: UUID
    let text: String
    let created_at: Date
    
    // Optional: for display purposes
    var username: String?
}

// MARK: - Codable Conformance (Non-isolated)

extension VideoLike: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case video_id
        case created_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.user_id = try container.decode(UUID.self, forKey: .user_id)
        self.video_id = try container.decode(UUID.self, forKey: .video_id)
        self.created_at = try container.decode(Date.self, forKey: .created_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(video_id, forKey: .video_id)
        try container.encode(created_at, forKey: .created_at)
    }
}

extension VideoComment: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case video_id
        case user_id
        case text
        case created_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.video_id = try container.decode(UUID.self, forKey: .video_id)
        self.user_id = try container.decode(UUID.self, forKey: .user_id)
        self.text = try container.decode(String.self, forKey: .text)
        self.created_at = try container.decode(Date.self, forKey: .created_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(video_id, forKey: .video_id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(text, forKey: .text)
        try container.encode(created_at, forKey: .created_at)
    }
}

// MARK: - Social Store

@MainActor
final class SocialStore: ObservableObject {
    @Published var errorText: String?
    
    private let client = SupabaseConfig.shared.client
    
    // MARK: - Likes
    
    func isLiked(videoId: UUID, userId: UUID) async -> Bool {
        do {
            let query = await client.database
                .from("likes")
                .select()
                .eq("video_id", value: videoId.uuidString)
                .eq("user_id", value: userId.uuidString)
            
            let likes: [VideoLike] = try await query
                .execute()
                .value
            
            return !likes.isEmpty
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }
    
    func toggleLike(videoId: UUID, userId: UUID, currentlyLiked: Bool) async throws {
        if currentlyLiked {
            // Unlike
            let deleteQuery = await client.database
                .from("likes")
                .delete()
                .eq("video_id", value: videoId.uuidString)
                .eq("user_id", value: userId.uuidString)
            
            try await deleteQuery.execute()
        } else {
            // Like
            let like = VideoLike(
                id: UUID(),
                user_id: userId,
                video_id: videoId,
                created_at: Date()
            )
            
            let insertQuery = try! await client.database
                .from("likes")
                .insert(like)
            
            try await insertQuery.execute()
        }
    }
    
    // MARK: - Comments
    
    func fetchComments(videoId: UUID) async throws -> [VideoComment] {
        let query = await client.database
            .from("comments")
            .select()
            .eq("video_id", value: videoId.uuidString)
            .order("created_at", ascending: false)
        
        let comments: [VideoComment] = try await query
            .execute()
            .value
        
        return comments
    }
    
    func addComment(videoId: UUID, userId: UUID, body: String) async throws -> VideoComment {
        let comment = VideoComment(
            id: UUID(),
            video_id: videoId,
            user_id: userId,
            text: body,
            created_at: Date()
        )
        
        let query = try await client.database
            .from("comments")
            .insert(comment)
            .select()
            .single()
        
        let inserted: VideoComment = try await query
            .execute()
            .value
        
        return inserted
    }
    
    // Add a public Comment typealias for easier access
    typealias Comment = VideoComment
}
