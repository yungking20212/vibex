//
//  VideoUploader.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import PhotosUI
import Supabase
import UniformTypeIdentifiers
import Combine
import SwiftUI
import AVFoundation

// MARK: - Video Insert Model (Outside @MainActor)

struct VideoInsert: Codable, Sendable {
    let id: String
    let user_id: String
    let username: String
    let caption: String?
    let video_url: String
    let thumbnail_url: String?
    let likes: Int
    let comments: Int
    let shares: Int
    let views: Int
}

// Ensure `VideoInsert` Codable conformance is nonisolated so it can be used
// from detached/background contexts (e.g., `Task.detached`) without actor
// isolation issues.
extension VideoInsert {
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case username
        case caption
        case video_url
        case thumbnail_url
        case likes
        case comments
        case shares
        case views
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.user_id = try container.decode(String.self, forKey: .user_id)
        self.username = try container.decode(String.self, forKey: .username)
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption)
        self.video_url = try container.decode(String.self, forKey: .video_url)
        self.thumbnail_url = try container.decodeIfPresent(String.self, forKey: .thumbnail_url)
        self.likes = try container.decode(Int.self, forKey: .likes)
        self.comments = try container.decode(Int.self, forKey: .comments)
        self.shares = try container.decode(Int.self, forKey: .shares)
        self.views = try container.decode(Int.self, forKey: .views)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(video_url, forKey: .video_url)
        try container.encodeIfPresent(thumbnail_url, forKey: .thumbnail_url)
        try container.encode(likes, forKey: .likes)
        try container.encode(comments, forKey: .comments)
        try container.encode(shares, forKey: .shares)
        try container.encode(views, forKey: .views)
    }
}

// MARK: - Video Uploader

@MainActor
final class VideoUploader: ObservableObject {
    @Published var isUploading = false
    @Published var progress: Double = 0
    @Published var errorText: String?

    private let client = SupabaseConfig.shared.client

    private func generateThumbnail(from data: Data, at time: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600)) -> Data? {
        // Write data to a temporary file URL so AVAsset can read it
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        do { try data.write(to: tmpURL) } catch { return nil }

        let asset = AVAsset(url: tmpURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 0.8)
        } catch {
            return nil
        }
    }

    func upload(pickerItem: PhotosPickerItem, caption: String, userId: UUID, username: String) async -> UUID? {
        errorText = nil
        isUploading = true
        progress = 0
        defer { isUploading = false }

        do {
            // 1) Load data from PhotosPicker
            guard let videoData = try await pickerItem.loadTransferable(type: Data.self) else {
                errorText = "Could not load video data."
                return nil
            }
            progress = 0.2

            // 2) Prepare storage path
            let videoId = UUID()
            let fileName = "\(videoId.uuidString).mp4"
            let objectPath = "\(userId.uuidString)/\(fileName)"
            let fullPath = objectPath

            // 3) Upload to Storage bucket `videos`
            _ = try await client.storage
                .from(SupabaseConfig.bucketVideos)
                .upload(
                    path: fullPath,
                    file: videoData,
                    options: FileOptions(contentType: "video/mp4", upsert: false)
                )

            progress = 0.75

            // Generate thumbnail JPEG data
            let thumbData = generateThumbnail(from: videoData)
            var thumbnailPublicURLString: String? = nil
            if let thumbData = thumbData {
                let thumbName = "\(videoId.uuidString).jpg"
                let thumbPath = "thumbnails/\(userId.uuidString)/\(thumbName)"
                _ = try? await client.storage
                    .from(SupabaseConfig.bucketVideos)
                    .upload(path: thumbPath, file: thumbData, options: FileOptions(contentType: "image/jpeg", upsert: false))
                // Try to get public URL even if upload may have failed silently; callers can handle nil
                let thumbURL = try? client.storage
                    .from(SupabaseConfig.bucketVideos)
                    .getPublicURL(path: thumbPath)
                thumbnailPublicURLString = thumbURL?.absoluteString
            }

            progress = 0.9

            // 4) Get public URL
            let publicURL = try client.storage
                .from(SupabaseConfig.bucketVideos)
                .getPublicURL(path: fullPath)
            
            let videoURL = publicURL.absoluteString

            // 5) Insert DB row using VideoInsert struct
            // Capture values in nonisolated context to avoid actor isolation issues
            let videoIdString = videoId.uuidString
            let userIdString = userId.uuidString
            let captionValue = caption.isEmpty ? nil : caption
            let usernameValue = username
            let thumbnailURLValue = thumbnailPublicURLString
            
            let insertResult = try await Task.detached {
                let videoInsert = VideoInsert(
                    id: videoIdString,
                    user_id: userIdString,
                    username: usernameValue,
                    caption: captionValue,
                    video_url: videoURL,
                    thumbnail_url: thumbnailURLValue,
                    likes: 0,
                    comments: 0,
                    shares: 0,
                    views: 0
                )
                
                return try await self.client.database
                    .from("videos")
                    .insert(videoInsert)
                    .execute()
            }.value

            progress = 1.0
            return videoId
        } catch {
            errorText = error.localizedDescription
            return nil
        }
    }
}

