//
//  SupabaseService.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import Supabase
import Realtime
import Combine
import UIKit

// ProfileUpdate used for DB updates must not be actor-isolated.
// Declare at file scope so Encodable conformance is not MainActor-isolated.
private struct ProfileUpdate: Sendable {
    let username: String?
    let display_name: String?
    let bio: String?
    let updated_at: String

    enum CodingKeys: String, CodingKey {
        case username
        case display_name
        case bio
        case updated_at
    }
}

// Provide a nonisolated `Encodable` implementation so the conformance
// can be used from concurrent contexts (avoids main-actor-isolated synthesized conformance).
extension ProfileUpdate: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(display_name, forKey: .display_name)
        try container.encode(bio, forKey: .bio)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

// MARK: - Supabase Service

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client = SupabaseConfig.shared.client
    
    private init() {}
    
    // MARK: - Video Management
    
    func fetchFeed(limit: Int = 20, offset: Int = 0) async throws -> [VideoPost] {
        let query = await client.database
            .from("videos")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
        
        let response: [VideoPost] = try await query
            .execute()
            .value
        
        return response
    }
    
    func fetchDiscoverVideos(limit: Int = 30) async throws -> [VideoPost] {
        do {
            let query = await client.database
                .from("videos")
                .select()
                .order("views", ascending: false)
                .order("likes", ascending: false)
                .limit(limit)

            let response: [VideoPost] = try await query
                .execute()
                .value

            let boosted = response.stablePartition { $0.likes >= 10_000 }
            return boosted
        } catch {
            // Some Supabase instances or migrations may not have a `views` column.
            // Fall back to ordering by `likes` (then `created_at`) to keep discover working.
            print("fetchDiscoverVideos: failed ordering by views, falling back: \(error)")

            let fallbackQuery = await client.database
                .from("videos")
                .select()
                .order("likes", ascending: false)
                .limit(limit)

            let response: [VideoPost] = try await fallbackQuery
                .execute()
                .value

            let boosted = response.stablePartition { $0.likes >= 10_000 }
            return boosted
        }
    }
    
    func fetchUserVideos(userId: String) async throws -> [VideoPost] {
        let query = await client.database
            .from("videos")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
        
        let response: [VideoPost] = try await query
            .execute()
            .value
        
        return response
    }

    /// Streams a file to Supabase Storage using URLSession and reports byte-level progress.
    /// Returns the public URL for the uploaded object.
    func streamUploadToStorage(bucket: String, path: String, fileURL: URL, contentType: String = "video/mp4", progress: @escaping (Double) -> Void) async throws -> URL {
        // Build the REST endpoint for Storage object upload
        let baseURL = SupabaseConfig.shared.supabaseURL.absoluteString
        let apiKey = SupabaseConfig.shared.supabaseKey
        // Ensure the object path is percent-encoded to avoid invalid URL issues
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let uploadURL = URL(string: "\(baseURL)/storage/v1/object/\(bucket)/\(encodedPath)") else {
            throw URLError(.badURL)
        }

        // Create a background-capable session and delegate object to surface progress
        class ProgressDelegate: NSObject, URLSessionTaskDelegate {
            let onProgress: (Double) -> Void
            let totalBytes: Int64
            init(totalBytes: Int64, onProgress: @escaping (Double) -> Void) {
                self.totalBytes = totalBytes
                self.onProgress = onProgress
            }
            func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
                let denom = totalBytesExpectedToSend > 0 ? Double(totalBytesExpectedToSend) : Double(totalBytes)
                let value = denom > 0 ? Double(totalBytesSent) / denom : 0
                DispatchQueue.main.async { self.onProgress(min(max(value, 0), 1)) }
            }
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        let delegate = ProgressDelegate(totalBytes: fileSize, onProgress: progress)
        let config = URLSessionConfiguration.background(withIdentifier: "vx.upload.\(UUID().uuidString)")
        config.allowsConstrainedNetworkAccess = true
        config.allowsCellularAccess = true
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST" // Supabase Storage accepts POST to /object/{bucket}/{path}

        // Use the authenticated user's access token to satisfy RLS
        let authSession = try await SupabaseConfig.shared.client.auth.session
        let userToken = authSession.accessToken
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")

        // Include the Supabase API key header — some Supabase endpoints require this
        // in addition to the Authorization bearer token for proper routing/auth.
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")

        print("[StorageStream] Uploading to: \(uploadURL.absoluteString), auth=Bearer <token masked>, bucket=\(bucket), path=\(path)")

        let task = session.uploadTask(with: request, fromFile: fileURL)
        return try await withCheckedThrowingContinuation { cont in
            task.resume()
            task.taskDescription = path

            // Completion handler via delegate not available on background session easily; use task’s completion handler via KVO workaround
            // Simpler approach: add a completion handler with a dataTask after upload to get public URL
            task.priority = URLSessionTask.defaultPriority

            // Observe state until completed
            Task.detached { [weak session] in
                while task.state != .completed {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                // After completion, check for error
                if let error = task.error { cont.resume(throwing: error); return }
                do {
                    let publicURL = try SupabaseConfig.shared.client.storage
                        .from(bucket)
                        .getPublicURL(path: path)
                    cont.resume(returning: publicURL)
                } catch {
                    cont.resume(throwing: error)
                }
                session?.invalidateAndCancel()
            }
        }
    }

    /// Uploads a video file with true streaming progress and creates a DB row. Optionally uploads a thumbnail.
    func uploadVideoStreaming(caption: String, fileURL: URL, userId: String, username: String, thumbnailData: Data?, progress: @escaping (Double) -> Void) async throws -> VideoPost {
        let fileName = "\(UUID().uuidString).mp4"
        let videoPath = "\(userId)/\(fileName)"
        let videoURL = try await streamUploadToStorage(bucket: "videos", path: videoPath, fileURL: fileURL, contentType: "video/mp4", progress: progress)

        // Insert DB row
        let inserted: VideoPost = try await client.database
            .from("videos")
            .insert(
                VideoPost(
                    id: UUID().uuidString,
                    userId: userId,
                    username: username,
                    caption: caption,
                    videoURL: videoURL.absoluteString,
                    thumbnailURL: nil,
                    likes: 0,
                    comments: 0,
                    shares: 0,
                    views: 0,
                    createdAt: Date()
                )
            )
            .select()
            .single()
            .execute()
            .value

        var finalPost = inserted

        // Upload thumbnail if provided and update DB
        if let thumbnailData {
            let thumbName = "\(UUID().uuidString).jpg"
            let thumbPath = "\(userId)/\(thumbName)"
            let thumbURL = try await streamUploadToStorage(bucket: "thumbnails", path: thumbPath, fileURL: writeTemp(data: thumbnailData, ext: "jpg"), contentType: "image/jpeg", progress: { _ in })
            _ = try await client.database
                .from("videos")
                .update(["thumbnail_url": thumbURL.absoluteString])
                .eq("id", value: finalPost.id)
                .execute()
            finalPost = VideoPost(
                id: finalPost.id,
                userId: finalPost.userId,
                username: finalPost.username,
                caption: finalPost.caption,
                videoURL: finalPost.videoURL,
                thumbnailURL: thumbURL.absoluteString,
                likes: finalPost.likes,
                comments: finalPost.comments,
                shares: finalPost.shares,
                views: finalPost.views,
                createdAt: finalPost.createdAt
            )
        }

        return finalPost
    }

    private func writeTemp(data: Data, ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try? data.write(to: url)
        return url
    }
    
    func uploadVideo(caption: String, videoData: Data, userId: String, username: String) async throws -> VideoPost {
        // Upload video file to storage
        let fileName = "\(UUID().uuidString).mp4"
        let filePath = "\(userId)/\(fileName)"
        
        try await client.storage
            .from("videos")
            .upload(
                path: filePath,
                file: videoData,
                options: FileOptions(contentType: "video/mp4")
            )
        
        // Get public URL
        let publicURL = try client.storage
            .from("videos")
            .getPublicURL(path: filePath)
        
        // Create video post
        let videoPost = VideoPost(
            id: UUID().uuidString,
            userId: userId,
            username: username,
            caption: caption,
            videoURL: publicURL.absoluteString,
            thumbnailURL: nil,
            likes: 0,
            comments: 0,
            shares: 0,
            views: 0,
            createdAt: Date()
        )
        
        let query = try await client.database
            .from("videos")
            .insert(videoPost)
            .select()
            .single()
        
        let response: VideoPost = try await query
            .execute()
            .value
        
        return response
    }
    
    func deleteVideo(videoId: String) async throws {
        let query = await client.database
            .from("videos")
            .delete()
            .eq("id", value: videoId)
        
        try await query.execute()
    }
    
    // MARK: - Likes
    
    func likeVideo(videoId: String, userId: String) async throws {
        let like = Like(
            id: UUID().uuidString,
            userId: userId,
            videoId: videoId,
            createdAt: Date()
        )
        
        let insertQuery = try? await client.database
            .from("likes")
            .insert(like)
        
        try await insertQuery?.execute()
        
        // Update video likes count
        let rpcQuery = try? await client.database
            .rpc("increment_likes", params: ["video_id": videoId])
        
        try await rpcQuery?.execute()
    }
    
    func unlikeVideo(videoId: String, userId: String) async throws {
        let deleteQuery = await client.database
            .from("likes")
            .delete()
            .eq("user_id", value: userId)
            .eq("video_id", value: videoId)
        
        try await deleteQuery.execute()
        
        // Update video likes count
        let rpcQuery = try? await client.database
            .rpc("decrement_likes", params: ["video_id": videoId])
        
        try await rpcQuery?.execute()
    }

    // MARK: - Views

    /// Increment views counter via RPC (requires `increment_views` function in DB)
    func incrementViews(videoId: String) async throws {
        let rpcQuery = try? await client.database
            .rpc("increment_views", params: ["video_id": videoId])
        try await rpcQuery?.execute()
    }
    
    /// Backwards-compatible wrapper matching call sites expecting `incrementViewCount(videoId:)`
    func incrementViewCount(videoId: String) async throws {
        try await incrementViews(videoId: videoId)
    }
    
    func isVideoLiked(videoId: String, userId: String) async throws -> Bool {
        let query = await client.database
            .from("likes")
            .select()
            .eq("user_id", value: userId)
            .eq("video_id", value: videoId)
        
        let response: [Like] = try await query
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    // MARK: - Comments
    
    func fetchComments(videoId: String) async throws -> [Comment] {
        let query = await client.database
            .from("comments")
            .select()
            .eq("video_id", value: videoId)
            .order("created_at", ascending: false)
        
        let response: [Comment] = try await query
            .execute()
            .value
        
        return response
    }
    
    func addComment(videoId: String, text: String, userId: String, username: String) async throws -> Comment {
        let comment = Comment(
            id: UUID().uuidString,
            videoId: videoId,
            userId: userId,
            username: username,
            text: text,
            likes: 0,
            createdAt: Date()
        )
        
        let query = try await client.database
            .from("comments")
            .insert(comment)
            .select()
            .single()
        
        let response: Comment = try await query
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Follows
    
    func followUser(userId: String, currentUserId: String) async throws {
        let follow = Follow(
            id: UUID().uuidString,
            followerId: currentUserId,
            followingId: userId,
            createdAt: Date()
        )
        
        let query = try await client.database
            .from("follows")
            .insert(follow)
        
        try await query.execute()
    }
    
    func unfollowUser(userId: String, currentUserId: String) async throws {
        let query = await client.database
            .from("follows")
            .delete()
            .eq("follower_id", value: currentUserId)
            .eq("following_id", value: userId)
        
        try await query.execute()
    }
    
    func isFollowing(userId: String, currentUserId: String) async throws -> Bool {
        let query = await client.database
            .from("follows")
            .select()
            .eq("follower_id", value: currentUserId)
            .eq("following_id", value: userId)
        
        let response: [Follow] = try await query
            .execute()
            .value
        
        return !response.isEmpty
    }

    // MARK: - Profile Images
    
    // ⚠️ LOCKED - DO NOT MODIFY - WORKING IMPLEMENTATION ⚠️
    // This function successfully handles avatar uploads with:
    // - Unique timestamped filenames to avoid conflicts
    // - Proper RLS policy compliance
    // - Clean error handling
    // Last verified: 2026-01-25
    /// Uploads a profile avatar to the `avatars` storage bucket and updates the
    /// `profiles.avatar_url` column. Returns the public URL for the uploaded image.
    func uploadProfileImage(userId: UUID, imageData: Data, contentType: String = "image/jpeg") async throws -> URL {
        // Use timestamp to ensure unique filename and avoid conflicts
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "avatar_\(timestamp).jpg"
        let filePath = "\(userId.uuidString)/\(fileName)"
        print("[Avatar] preparing upload: bucket=avatars, path=\(filePath)")

        do {
            // Upload the new avatar
            try await client.storage
                .from("avatars")
                .upload(path: filePath, file: imageData, options: FileOptions(contentType: contentType))
            print("[Avatar] storage upload success at path: \(filePath)")
        } catch {
            print("[Avatar] storage upload failed: \(error)")
            throw NSError(
                domain: "VibeX",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to upload image: \(error.localizedDescription)"]
            )
        }

        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        print("[Avatar] publicURL: \(publicURL.absoluteString)")

        // Update profile with new avatar URL
        do {
            _ = try await client.database
                .from("profiles")
                .update(["avatar_url": publicURL.absoluteString])
                .eq("id", value: userId.uuidString)
                .execute()
            print("[Avatar] profile updated with new avatar_url")
        } catch {
            print("[Avatar] profile update failed: \(error)")
            throw NSError(
                domain: "VibeX",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to update profile: \(error.localizedDescription)"]
            )
        }

        return publicURL
    }
    
    // MARK: - Profile Management
    
    /// Updates user profile fields (username, display_name, bio)
    /// Returns the updated profile on success
    func updateProfile(userId: UUID, username: String?, displayName: String?, bio: String?) async throws -> Profile {
        let updates = ProfileUpdate(
            username: username,
            display_name: displayName,
            bio: bio,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            let response: Profile = try await client.database
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            return response
        } catch {
            print("Profile update error: \(error)")
            throw NSError(
                domain: "VibeX",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to update profile: \(error.localizedDescription)"]
            )
        }
    }
    
    /// Fetches the current user's profile
    func fetchProfile(userId: UUID) async throws -> Profile {
        let response: Profile = try await client.database
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        return response
    }

    // MARK: - User Stats

    /// Fetch aggregated user stats from the `user_stats` view
    /// Returns nil if no row found for the given userId
    func fetchUserStats(userId: String) async throws -> UserStats? {
        let query = await client.database
            .from("user_stats")
            .select()
            .eq("user_id", value: userId)
            .single()

        let response: UserStats = try await query
            .execute()
            .value

        return response
    }

    // MARK: - Realtime subscriptions

    private var realtimeChannels: [String: RealtimeChannel] = [:]

    /// Subscribe to changes on the `videos` table and invoke the handler with the changed `VideoPost` and event type
    func subscribeToVideoChanges(handler: @escaping (_ event: String, _ post: VideoPost) -> Void) {
        let channelKey = "videos_changes"
        // Avoid double subscription
        if realtimeChannels[channelKey] != nil { return }

        Task { @MainActor in
            // TODO: Re-enable realtime once the correct Realtime API is available in dependencies.
            // Current project Realtime package lacks the Postgres helpers used previously.
            print("[SupabaseService] Realtime videos subscription disabled (API mismatch)")
        }
    }

    /// Subscribe to changes on the `likes` table to update like counts in realtime
    func subscribeToLikeChanges(handler: @escaping (_ event: String, _ likeId: String?, _ videoId: String?) -> Void) {
        let channelKey = "likes_changes"
        if realtimeChannels[channelKey] != nil { return }

        Task { @MainActor in
            // TODO: Re-enable realtime once the correct Realtime API is available in dependencies.
            print("[SupabaseService] Realtime likes subscription disabled (API mismatch)")
        }
    }

    /// Subscribe to changes on the `comments` table to update comment counts in realtime
    func subscribeToCommentChanges(handler: @escaping (_ event: String, _ commentId: String?, _ videoId: String?) -> Void) {
        let channelKey = "comments_changes"
        if realtimeChannels[channelKey] != nil { return }

        Task { @MainActor in
            // TODO: Re-enable realtime once the correct Realtime API is available in dependencies.
            print("[SupabaseService] Realtime comments subscription disabled (API mismatch)")
        }
    }

    /// Unsubscribe from all realtime channels (call on app shutdown)
    func unsubscribeAllRealtime() {
        for (_, ch) in realtimeChannels {
            Task { try? await ch.unsubscribe() }
        }
        realtimeChannels.removeAll()
    }
    
    // MARK: - User Search

    /// Searches profiles by username or display_name (case-insensitive)
    /// - Parameters:
    ///   - query: The search text. Leading/trailing whitespace will be trimmed.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Array of lightweight UserProfile objects used by Discover.
    func searchUsers(query: String, limit: Int = 10) async throws -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Attempt ilike on username OR display_name. If the backend doesn't support OR easily,
        // run two simple queries and merge unique results client-side.
        // First: username matches
        let usernameMatches: [Profile] = try await client.database
            .from("profiles")
            .select()
            .ilike("username", value: "%\(trimmed)%")
            .limit(limit)
            .execute()
            .value

        var results = usernameMatches

        // If we still have room, query display_name too
        if results.count < limit {
            let remaining = limit - results.count
            let displayMatches: [Profile] = try await client.database
                .from("profiles")
                .select()
                .ilike("display_name", value: "%\(trimmed)%")
                .limit(remaining)
                .execute()
                .value

            // Merge without duplicates (by id)
            let existingIds = Set(results.map { $0.id })
            let uniques = displayMatches.filter { !existingIds.contains($0.id) }
            results.append(contentsOf: uniques)
        }

        // Map to lightweight UserProfile used by Discover
        let mapped: [UserProfile] = results.map { p in
            UserProfile(
                id: p.id,
                username: p.username ?? "",
                display_name: p.display_name,
                bio: p.bio
            )
        }

        return mapped
    }
}

extension Array {
    /// Returns a new array where all elements satisfying the predicate appear first,
    /// preserving the relative order of both groups (stable partition).
    func stablePartition(by predicate: (Element) -> Bool) -> [Element] {
        var matching: [Element] = []
        var nonMatching: [Element] = []
        matching.reserveCapacity(count)
        nonMatching.reserveCapacity(count)
        for e in self {
            if predicate(e) { matching.append(e) } else { nonMatching.append(e) }
        }
        return matching + nonMatching
    }
}

