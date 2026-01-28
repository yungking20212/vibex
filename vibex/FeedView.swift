//
//  FeedView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI
import AVKit
import Supabase

// MARK: - Modern Feed View

struct ModernFeedView: View {
    @EnvironmentObject var auth: AuthManager
    @StateObject private var store = FeedStore()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.items) { item in
                    FeedCell(video: item)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                        .onAppear {
                            Task { await store.loadMoreIfNeeded(currentItem: item) }
                        }
                }

                if store.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Feed")
            .toolbar {
                Button("Refresh") { Task { await store.refresh() } }
            }
            .task {
                await store.refresh()
            }
            .overlay {
                if let err = store.errorText {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
        }
    }
}

// MARK: - Feed Cell

struct FeedCell: View {
    let video: FeedVideo
    @EnvironmentObject var auth: AuthManager
    @StateObject private var social = SocialStore()

    @State private var player: AVPlayer?
    @State private var liked: Bool = false
    @State private var showComments = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VideoPlayer(player: player)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .onAppear {
                    if player == nil {
                        player = AVPlayer(url: URL(string: video.video_url)!)
                        player?.isMuted = true
                        player?.play()
                    }
                    Task {
                        guard let uid = auth.session?.user.id else { return }
                        liked = await social.isLiked(videoId: video.id, userId: uid)
                    }
                }
                .onDisappear { player?.pause() }

            if let caption = video.caption, !caption.isEmpty {
                Text(caption).font(.headline)
            }

            HStack(spacing: 14) {
                Button {
                    Task {
                        do {
                            guard let uid = auth.session?.user.id else { return }
                            let current = liked
                            liked.toggle()
                            // Optimistic update: notify FeedStore to update counts immediately
                            NotificationCenter.default.post(name: .localLikeToggled, object: nil, userInfo: ["videoId": video.id.uuidString, "delta": (liked ? 1 : -1)])
                            try await social.toggleLike(videoId: video.id, userId: uid, currentlyLiked: current)
                        } catch {
                            errorText = error.localizedDescription
                            liked.toggle() // revert
                        }
                    }
                } label: {
                    Label("\(video.like_count) ", systemImage: liked ? "heart.fill" : "heart")
                }

                Button {
                    showComments = true
                } label: {
                    Label("\(video.comment_count) ", systemImage: "message")
                }

                Spacer()
            }
            .buttonStyle(.borderless)

            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(videoId: video.id)
                .environmentObject(auth)
        }
    }
}

// MARK: - Preview

#Preview {
    ModernFeedView()
        .environmentObject(AuthManager.shared)
}
