//
//  FeedStore.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import Supabase
import Combine

// MARK: - Feed Video Model

struct FeedVideo: Identifiable, Equatable, Sendable {
    let id: UUID
    let user_id: UUID
    let caption: String?
    let video_url: String
    let video_path: String
    let username: String
    let like_count: Int
    let comment_count: Int
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case caption
        case video_url
        case video_path
        case username
        case like_count
        case comment_count
        case created_at
    }
}

extension FeedVideo: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.user_id = try container.decode(UUID.self, forKey: .user_id)
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
        self.video_url = try container.decode(String.self, forKey: .video_url)
        self.video_path = try container.decode(String.self, forKey: .video_path)
        self.username = try container.decode(String.self, forKey: .username)
        self.like_count = try container.decode(Int.self, forKey: .like_count)
        self.comment_count = try container.decode(Int.self, forKey: .comment_count)
        self.created_at = try container.decode(Date.self, forKey: .created_at)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(video_url, forKey: .video_url)
        try container.encode(video_path, forKey: .video_path)
        try container.encode(username, forKey: .username)
        try container.encode(like_count, forKey: .like_count)
        try container.encode(comment_count, forKey: .comment_count)
        try container.encode(created_at, forKey: .created_at)
    }
}

// MARK: - Feed Store

@MainActor
final class FeedStore: ObservableObject {
    @Published var items: [FeedVideo] = []
    @Published var isLoading = false
    @Published var errorText: String?

    private let client = SupabaseConfig.shared.client

    private var pageSize: Int = 10
    private var currentOffset: Int = 0
    private var canLoadMore: Bool = true
    private var subscriptionsInitialized = false

    init() {
        Task { await subscribeRealtime() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func subscribeRealtime() async {
        guard !subscriptionsInitialized else { return }
        subscriptionsInitialized = true

        // Subscribe to video changes
        SupabaseService.shared.subscribeToVideoChanges { [weak self] event, post in
            Task { @MainActor in
                guard let self = self else { return }
                let vid = UUID(uuidString: post.id) ?? UUID()
                switch event.uppercased() {
                case "INSERT":
                    // Prepend new video to the list
                    let fv = FeedVideo(id: vid,
                                      user_id: UUID(uuidString: post.userId) ?? UUID(),
                                      caption: post.caption,
                                      video_url: post.videoURL,
                                      video_path: post.videoURL,
                                      username: post.username,
                                      like_count: post.likes,
                                      comment_count: post.comments,
                                      created_at: post.createdAt)
                    self.items.insert(fv, at: 0)
                case "UPDATE":
                    if let idx = self.items.firstIndex(where: { $0.id == vid }) {
                        var existing = self.items[idx]
                        existing = FeedVideo(id: existing.id,
                                             user_id: existing.user_id,
                                             caption: post.caption,
                                             video_url: post.videoURL,
                                             video_path: post.videoURL,
                                             username: post.username,
                                             like_count: post.likes,
                                             comment_count: post.comments,
                                             created_at: post.createdAt)
                        self.items[idx] = existing
                    }
                case "DELETE":
                    if let idx = self.items.firstIndex(where: { $0.id == vid }) {
                        self.items.remove(at: idx)
                    }
                default:
                    break
                }
            }
        }

        // Subscribe to likes changes to update counts locally
        SupabaseService.shared.subscribeToLikeChanges { [weak self] event, likeId, videoId in
            Task { @MainActor in
                guard let self = self, let vidStr = videoId, let vid = UUID(uuidString: vidStr) else { return }
                if let idx = self.items.firstIndex(where: { $0.id == vid }) {
                    var v = self.items[idx]
                    if event.uppercased() == "INSERT" {
                        v = FeedVideo(id: v.id, user_id: v.user_id, caption: v.caption, video_url: v.video_url, video_path: v.video_path, username: v.username, like_count: v.like_count + 1, comment_count: v.comment_count, created_at: v.created_at)
                    } else if event.uppercased() == "DELETE" {
                        v = FeedVideo(id: v.id, user_id: v.user_id, caption: v.caption, video_url: v.video_url, video_path: v.video_path, username: v.username, like_count: max(0, v.like_count - 1), comment_count: v.comment_count, created_at: v.created_at)
                    }
                    self.items[idx] = v
                }
            }
        }

        // Subscribe to comments changes to update comment counts locally
        SupabaseService.shared.subscribeToCommentChanges { [weak self] event, commentId, videoId in
            Task { @MainActor in
                guard let self = self, let vidStr = videoId, let vid = UUID(uuidString: vidStr) else { return }
                if let idx = self.items.firstIndex(where: { $0.id == vid }) {
                    var v = self.items[idx]
                    if event.uppercased() == "INSERT" {
                        v = FeedVideo(id: v.id, user_id: v.user_id, caption: v.caption, video_url: v.video_url, video_path: v.video_path, username: v.username, like_count: v.like_count, comment_count: v.comment_count + 1, created_at: v.created_at)
                    } else if event.uppercased() == "DELETE" {
                        v = FeedVideo(id: v.id, user_id: v.user_id, caption: v.caption, video_url: v.video_url, video_path: v.video_path, username: v.username, like_count: v.like_count, comment_count: max(0, v.comment_count - 1), created_at: v.created_at)
                    }
                    self.items[idx] = v
                }
            }
        }

        // Register local optimistic observers
        registerLocalObservers()
    }

    private func registerLocalObservers() {
        NotificationCenter.default.addObserver(forName: .localLikeToggled, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            guard let info = note.userInfo,
                  let vidStr = info["videoId"] as? String,
                  let delta = info["delta"] as? Int,
                  let vid = UUID(uuidString: vidStr) else { return }

            if let idx = self.items.firstIndex(where: { $0.id == vid }) {
                var v = self.items[idx]
                let newLikes = max(0, v.like_count + delta)
                v = FeedVideo(id: v.id, user_id: v.user_id, caption: v.caption, video_url: v.video_url, video_path: v.video_path, username: v.username, like_count: newLikes, comment_count: v.comment_count, created_at: v.created_at)
                self.items[idx] = v
            }
        }
        NotificationCenter.default.addObserver(forName: .localViewCounted, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            guard let info = note.userInfo,
                  let vidStr = info["videoId"] as? String,
                  let vid = UUID(uuidString: vidStr) else { return }

            if let idx = self.items.firstIndex(where: { $0.id == vid }) {
                var v = self.items[idx]
                v = FeedVideo(id: v.id, user_id: v.user_id, caption: v.caption, video_url: v.video_url, video_path: v.video_path, username: v.username, like_count: v.like_count, comment_count: v.comment_count, created_at: v.created_at)
                // increment views are not stored on FeedVideo model; if desired, consider adding views to FeedVideo
                self.items[idx] = v
            }
        }
    }

    func refresh() async {
        items = []
        currentOffset = 0
        canLoadMore = true
        await loadMoreIfNeeded(currentItem: nil)
    }

    func loadMoreIfNeeded(currentItem: FeedVideo?) async {
        guard !isLoading, canLoadMore else { return }

        if let currentItem,
           let last = items.last,
           currentItem.id != last.id {
            return // only load when we reach the end item
        }

        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let page: [FeedVideo] = try await client.database
                .from("videos")
                .select()
                .order("created_at", ascending: false)
                .range(from: currentOffset, to: currentOffset + pageSize - 1)
                .execute()
                .value

            if page.count < pageSize { canLoadMore = false }
            currentOffset += page.count
            items.append(contentsOf: page)

        } catch {
            errorText = error.localizedDescription
        }
    }
}
