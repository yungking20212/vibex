//
//  VideoFeedViewModel.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class VideoFeedViewModel: ObservableObject {
    @Published var items: [FeedVideo] = []
    @Published var isLoading = false
    @Published var errorText: String?

    private let pageSize = 8
    private var offset = 0
    private var canLoadMore = true

    func refresh() async {
        items = []
        offset = 0
        canLoadMore = true
        await loadMoreIfNeeded(currentIndex: nil)
    }

    func loadMoreIfNeeded(currentIndex: Int?) async {
        guard !isLoading, canLoadMore else { return }

        // Only load more when user is near the end
        if let currentIndex, currentIndex < items.count - 3 { return }

        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            // Use SupabaseService to centralize DB access and mapping
            let pagePosts = try await SupabaseService.shared.fetchFeed(limit: pageSize, offset: offset)

            let page: [FeedVideo] = pagePosts.map { post in
                let vid = UUID(uuidString: post.id) ?? UUID()
                let uid = UUID(uuidString: post.userId) ?? UUID()
                return FeedVideo(
                    id: vid,
                    user_id: uid,
                    caption: ((post.caption?.isEmpty) != nil) ? nil : post.caption,
                    video_url: post.videoURL,
                    video_path: post.videoURL, // placeholder; server may provide a storage path
                    username: post.username,
                    like_count: post.likes,
                    comment_count: post.comments,
                    created_at: post.createdAt
                )
            }

            if page.count < pageSize { canLoadMore = false }
            offset += page.count
            items.append(contentsOf: page)

        } catch {
            errorText = error.localizedDescription
        }
    }
}
