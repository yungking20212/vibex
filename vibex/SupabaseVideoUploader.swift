import Foundation
import UIKit
import Combine
import Supabase
import AVFoundation

@MainActor
final class SupabaseVideoUploader: ObservableObject {
    @Published var isUploading = false
    @Published var progress: Double = 0
    @Published var errorText: String?

    private let client = SupabaseConfig.shared.client
    private let bucket = "videos"

    private var currentTask: Task<UUID?, Never>? = nil
    private var lastParams: (fileURL: URL, caption: String?, userId: UUID)? = nil
    private var lastInsertPayload: UploaderVideoInsert? = nil

    // MARK: - Upload with progress support
    // Make final and mark as unchecked Sendable; ensure the progress handler is @Sendable
    private final class UploadDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        var progressHandler: @Sendable (Double) -> Void
        var continuation: CheckedContinuation<Void, Error>?
        var statusCode: Int? = nil

        init(progress: @escaping @Sendable (Double) -> Void) {
            self.progressHandler = progress
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            guard totalBytesExpectedToSend > 0 else { return }
            let p = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            DispatchQueue.main.async { self.progressHandler(p) }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let resp = task.response as? HTTPURLResponse {
                statusCode = resp.statusCode
            }
            if let err = error {
                print("[Uploader] upload error: \(err)")
                continuation?.resume(throwing: err)
            } else if let code = statusCode, !(200...299).contains(code) {
                let err = NSError(domain: "Upload", code: code, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(code)"])
                print("[Uploader] upload HTTP status: \(code)")
                continuation?.resume(throwing: err)
            } else {
                print("[Uploader] upload finished successfully (status: \(statusCode.map { String($0) } ?? "nil"))")
                continuation?.resume(returning: ())
            }
        }
    }

    private func uploadDataToURL(data: Data, to url: URL, objectPath: String, contentType: String) async throws {
        // Ensure we have a logged-in session and include the user's access token.
        enum UploadError: Error {
            case notAuthenticated
        }

        var session = try await SupabaseConfig.shared.client.auth.session
        var accessToken = session.accessToken
        guard !accessToken.isEmpty else {
            throw UploadError.notAuthenticated
        }

        // If token is expired or near expiry, attempt to refresh using the stored refresh token.
        func tokenIsExpiring(_ token: String) -> Bool {
            let comps = token.split(separator: ".")
            guard comps.count >= 2 else { return true }
            var payload = String(comps[1])
            let rem = payload.count % 4
            if rem != 0 { payload += String(repeating: "=", count: 4 - rem) }
            payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            guard let payloadData = Data(base64Encoded: payload),
                  let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                  let exp = obj["exp"] as? TimeInterval else { return true }
            // Consider expiring if within 60 seconds of expiry.
            return Date(timeIntervalSince1970: exp) <= Date().addingTimeInterval(60)
        }

        if tokenIsExpiring(accessToken) && !session.refreshToken.isEmpty {
            let refresh = session.refreshToken
            do {
                let authURL = SupabaseConfig.shared.supabaseURL.appendingPathComponent("auth/v1/token")
                var req = URLRequest(url: authURL)
                req.httpMethod = "POST"
                req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                // include anon key so the auth endpoint accepts the refresh
                req.setValue(SupabaseConfig.shared.supabaseKey, forHTTPHeaderField: "apikey")
                req.setValue("Bearer \(SupabaseConfig.shared.supabaseKey)", forHTTPHeaderField: "Authorization")
                let body = "grant_type=refresh_token&refresh_token=\(refresh)"
                req.httpBody = body.data(using: .utf8)

                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newAccess = json["access_token"] as? String {
                    accessToken = newAccess
                    // Capture new refresh token and expiry info if present and persist for other parts of the app to pick up.
                    let newRefresh = json["refresh_token"] as? String
                    let expiresIn: TimeInterval = {
                        if let v = json["expires_in"] as? Double { return v }
                        if let v = json["expires_in"] as? Int { return TimeInterval(v) }
                        if let s = json["expires_in"] as? String, let v = Double(s) { return v }
                        return 0
                    }()
                    let _ = json["token_type"] as? String
                    let _ = json["expires_at"] as? String

                    // Persist refreshed tokens in UserDefaults as a best-effort fallback so other app components can react.
                    UserDefaults.standard.setValue(newAccess, forKey: "supabase_refreshed_access_token")
                    if let rf = newRefresh { UserDefaults.standard.setValue(rf, forKey: "supabase_refreshed_refresh_token") }
                    NotificationCenter.default.post(name: Notification.Name("supabaseTokenRefreshed"), object: nil)

                    print("[Uploader] refreshed access token (masked): \(String(accessToken.prefix(min(8, accessToken.count))))…")
                } else {
                    print("[Uploader] token refresh failed, proceeding with existing token")
                }
            } catch {
                print("[Uploader] token refresh error: \(error)")
            }
        }

        // Mask token and log expiry for debugging (does not print full token)
        do {
            let masked = accessToken.count > 8 ? String(accessToken.prefix(8)) + "…" : accessToken
            let comps = accessToken.split(separator: ".")
            if comps.count >= 2 {
                var payload = String(comps[1])
                let rem = payload.count % 4
                if rem != 0 { payload += String(repeating: "=", count: 4 - rem) }
                payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                if let payloadData = Data(base64Encoded: payload),
                   let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                   let exp = obj["exp"] as? TimeInterval {
                    let expDate = Date(timeIntervalSince1970: exp)
                    print("[Uploader] access token (masked): \(masked), exp: \(expDate)")
                } else {
                    print("[Uploader] access token (masked): \(masked), payload decode failed")
                }
            } else {
                print("[Uploader] access token (masked): \(masked), token format invalid")
            }
        }

        // When using the Edge upload proxy, `url` will be the function endpoint.
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Always include anon key for Edge function routing
        if let anon = AppConfig.supabaseAnonKey, !anon.isEmpty {
            request.setValue(anon, forHTTPHeaderField: "apikey")
        } else {
            // Optional: log a warning if anon key is missing
            print("[Uploader] Warning: supabase anon key is missing; apikey header will not be set")
        }
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("supabase-swift/edge-upload", forHTTPHeaderField: "X-Client-Info")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(objectPath, forHTTPHeaderField: "x-object-path")
        // Pass the desired storage path via header so the Edge function can store it correctly
        // Caller should have built `url` as the Edge function endpoint.

        let delegate = UploadDelegate { [weak self] p in
            // Map the upload progress into the 0.2 -> 0.7 range used by the UI
            Task { @MainActor in
                self?.progress = 0.2 + (p * 0.5)
            }
        }

        let uploadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // DEBUG: print request destination and masked Authorization header
        do {
            let masked = accessToken.count > 8 ? String(accessToken.prefix(8)) + "…" : accessToken
            let apikeySet = (request.value(forHTTPHeaderField: "apikey") != nil)
            print("[Uploader] uploading to: \(request.url?.absoluteString ?? "<nil>")")
            print("[Uploader] request headers: apikey=\(apikeySet), Authorization=\(masked), X-Client-Info=\(request.value(forHTTPHeaderField: "X-Client-Info") ?? ""), Content-Type=\(request.value(forHTTPHeaderField: "Content-Type") ?? ""), x-object-path=\(request.value(forHTTPHeaderField: "x-object-path") ?? "")")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            delegate.continuation = cont
            // POST the raw bytes to the Edge function; it will read headers `x-object-path` and content-type
            let task = uploadSession.uploadTask(with: request, from: data)
            task.resume()
        }

        uploadSession.finishTasksAndInvalidate()

        // Allow session to clean up
        uploadSession.finishTasksAndInvalidate()
        print("[Uploader] uploadDataToURL: completed upload task (status: \(delegate.statusCode.map { String($0) } ?? "nil"))")
    }

    private func insertVideoRow(_ payload: UploaderVideoInsert) async throws {
        _ = try await SupabaseConfig.shared.client
            .database
            .from("videos")
            .insert(payload)
            .execute()
    }

    /// Generate JPEG thumbnail data from a local video file URL.
    private func generateThumbnailData(from url: URL, at time: CMTime = CMTime(seconds: 0.6, preferredTimescale: 600)) throws -> Data? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 1280)
        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        let ui = UIImage(cgImage: cgImage)
        return ui.jpegData(compressionQuality: 0.8)
    }

    func uploadVideoFile(fileURL: URL, caption: String?, userId: UUID, quality: VideoQuality? = nil) async -> UUID? {
        // Store params so we can retry later (MainActor-isolated)
        lastParams = (fileURL: fileURL, caption: caption, userId: userId)

        // Cancel any existing task
        currentTask?.cancel()

        let task = Task<UUID?, Never> {
            var compressedTempURL: URL? = nil

            await MainActor.run {
                self.errorText = nil
                self.isUploading = true
                self.progress = 0
            }

            defer {
                Task { @MainActor in self.isUploading = false }
            }

            do {
                try Task.checkCancellation()

                // Optionally compress before reading bytes
                var uploadURL = fileURL
                // use the outer-scoped compressedTempURL so we can clean up in catch blocks
                if let q = quality {
                    if let compressed = try await compressVideo(inputURL: fileURL, quality: q) {
                        uploadURL = compressed
                        compressedTempURL = compressed
                    }
                }

                // Get file size and prepare for streaming upload (avoid loading into memory)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: uploadURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                print("[Uploader] preparing upload: url=\(uploadURL.lastPathComponent), size=\(fileSize)B")
                try Task.checkCancellation()
                await MainActor.run { self.progress = 0.2 }

                do {
                    let sess = try await self.client.auth.session
                    let tokenPrefix = sess.accessToken.prefix(min(8, sess.accessToken.count))
                    print("[Uploader] auth user=\(sess.user.id) token=\(tokenPrefix)…")
                } catch {
                    print("[Uploader] auth session unavailable: \(error)")
                }

                let videoId = UUID()
                let objectPath = "\(userId.uuidString)/\(videoId.uuidString).mp4"

                try Task.checkCancellation()
                // Upload via Supabase Functions API; SDK wires auth headers for us.
                await MainActor.run { self.progress = max(self.progress, 0.25) }

                // Declare signedURL here before assigning below
                var signedURL: String? = nil

                do {
                    // Stream upload using SupabaseService to avoid buffering large files in memory
                    await MainActor.run { self.progress = max(self.progress, 0.3) }
                    print("[Uploader] starting streaming upload to bucket=\(self.bucket), path=\(objectPath), size=\(fileSize)B")
                    let publicURL = try await SupabaseService.shared.streamUploadToStorage(bucket: self.bucket, path: objectPath, fileURL: uploadURL, contentType: "video/mp4") { p in
                        Task { @MainActor in
                            self.progress = 0.2 + (p * 0.5)
                        }
                    }
                    print("[Uploader] stream upload returned URL: \(publicURL.absoluteString)")
                    await MainActor.run { self.progress = max(self.progress, 0.7) }
                    signedURL = publicURL.absoluteString
                } catch {
                    let msg = error.localizedDescription
                    print("[Uploader] storage upload error: \(msg)")
                    await MainActor.run {
                        if msg.lowercased().contains("exceed") || msg.lowercased().contains("size") || msg.lowercased().contains("too large") {
                            self.errorText = "Storage upload failed: file is too large. Try 1080p or compress the video."
                        } else {
                            self.errorText = "Storage upload failed: \(msg)"
                        }
                        self.progress = 0.0
                    }
                    return nil
                }

                // give storage a small moment to finalize the object
                try await Task.sleep(nanoseconds: 1_500_000_000)

                // Extra post-upload visibility probe before signed URL attempts (more robust retries)
                let parentDir = (objectPath as NSString).deletingLastPathComponent
                var foundObject = false
                var listDelay: UInt64 = 500_000_000 // 0.5s
                let listMaxAttempts = 6
                for attempt in 0..<listMaxAttempts {
                    do {
                        let list = try await self.client.storage
                            .from(self.bucket)
                            .list(path: parentDir.isEmpty ? nil : parentDir)
                        let found = list.contains { $0.name == (objectPath as NSString).lastPathComponent }
                        print("[Uploader] post-upload visibility check \(attempt): found=\(found), count=\(list.count)")
                        if found { foundObject = true; break }
                    } catch {
                        print("[Uploader] post-upload list failed (attempt \(attempt)): \(error)")
                    }
                    try await Task.sleep(nanoseconds: listDelay)
                    listDelay = min(listDelay * 2, 5_000_000_000) // cap at 5s
                }

                // Do NOT abort on !foundObject here; proceed to signed URL attempts below. Storage listing can lag even when the object is retrievable.

                try Task.checkCancellation()
                // Removed the line: await MainActor.run { self.progress = 0.7 }

                try Task.checkCancellation()
                // Sometimes storage needs a moment before the object is visible to createSignedURL.
                // Retry a few times if we get an "object not found" type error.
                var retryDelay: UInt64 = 500_000_000 // 500ms
                let maxAttempts = 8
                for attempt in 0..<maxAttempts {
                    do {
                        print("[Uploader] attempting createSignedURL for: \(objectPath) (bucket: \(self.bucket)), attempt: \(attempt)")
                        let urlString = try await self.client.storage
                            .from(self.bucket)
                            .createSignedURL(path: objectPath, expiresIn: 60 * 60 * 24)
                            .absoluteString
                        signedURL = urlString
                        break
                    } catch {
                        print("[Uploader] createSignedURL attempt \(attempt) failed: \(error)")
                        // As a fallback, try listing the directory to confirm visibility
                        do {
                            let dir = (objectPath as NSString).deletingLastPathComponent
                            let list = try await self.client.storage
                                .from(self.bucket)
                                .list(path: dir.isEmpty ? nil : dir)
                            let found = list.contains(where: { $0.name == (objectPath as NSString).lastPathComponent })
                            print("[Uploader] list check in \(dir.isEmpty ? "/" : dir): found=\(found), count=\(list.count)")
                        } catch {
                            print("[Uploader] listing fallback failed: \(error)")
                        }
                        try await Task.sleep(nanoseconds: retryDelay)
                        retryDelay = min(retryDelay * 2, 5_000_000_000) // cap at 5s
                    }
                }

                if signedURL == nil {
                    // Fallback for public buckets: try generating a public URL
                    do {
                        let publicURL = try self.client.storage
                            .from(self.bucket)
                            .getPublicURL(path: objectPath)
                            .absoluteString
                        if !publicURL.isEmpty {
                            print("[Uploader] createSignedURL failed; using public URL fallback: \(publicURL)")
                            signedURL = publicURL
                        } else {
                            print("[Uploader] public URL fallback returned empty for path=\(objectPath)")
                        }
                    } catch {
                        print("[Uploader] public URL fallback failed: \(error)")
                    }
                }

                guard let finalSignedURL = signedURL else {
                    await MainActor.run {
                        self.errorText = "Upload completed, but we couldn't locate the object yet. Please wait a moment and tap Retry."
                        self.progress = 0.0
                    }
                    return nil
                }

                try Task.checkCancellation()
                await MainActor.run { self.progress = 0.85 }

                // Fetch the uploader's username for the required `username` column
                var usernameValue: String = "user"
                do {
                    if let profile: Profile = try await self.client.database
                        .from("profiles")
                        .select()
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value {
                        usernameValue = profile.username!
                    }
                } catch {
                    print("[Uploader] failed to fetch profile for username: \(error)")
                }

                // Attempt to generate and upload a thumbnail image from the uploaded video so the profile/feed shows a real preview immediately
                var thumbnailURLString: String? = nil
                do {
                    let sourceForThumb = compressedTempURL ?? fileURL
                    if let thumbData = try generateThumbnailData(from: sourceForThumb) {
                        let thumbName = "thumb_\(UUID().uuidString).jpg"
                        let thumbPath = "\(userId.uuidString)/\(thumbName)"
                        // Upload thumbnail to `thumbnails` bucket
                        do {
                            try await SupabaseConfig.shared.client.storage
                                .from("thumbnails")
                                .upload(path: thumbPath, file: thumbData, options: FileOptions(contentType: "image/jpeg"))
                            let thumbURL = try SupabaseConfig.shared.client.storage.from("thumbnails").getPublicURL(path: thumbPath)
                            thumbnailURLString = thumbURL.absoluteString
                        } catch {
                            print("[Uploader] thumbnail upload failed: \(error)")
                        }
                    }
                } catch {
                    print("[Uploader] thumbnail generation failed: \(error)")
                }

                let payload = UploaderVideoInsert(
                    id: videoId.uuidString,
                    user_id: userId.uuidString,
                    username: usernameValue,
                    caption: (caption?.isEmpty ?? true) ? nil : caption,
                    video_url: finalSignedURL,
                    thumbnail_url: thumbnailURLString
                )

                try Task.checkCancellation()
                lastInsertPayload = payload

                // Log payload details for debugging visibility / user_id mismatches
                print("[Uploader] inserting metadata: user_id=\(payload.user_id), username=\(payload.username), video_url=\(payload.video_url)")

                do {
                    try await insertVideoRow(payload)
                    lastInsertPayload = nil
                    print("[Uploader] metadata insert succeeded for videoId=\(videoId) (user_id=\(payload.user_id))")
                } catch {
                    print("[Uploader] insertVideoRow failed: \(error)")
                    await MainActor.run {
                        // Preserve the payload so `Finalize Metadata` can retry
                        self.lastInsertPayload = payload
                        self.errorText = "Upload stored, but failed to save metadata: \(error.localizedDescription). Tap 'Finalize Metadata' to retry."
                        // keep progress near completion to indicate upload succeeded
                        self.progress = 0.9
                    }
                    return nil
                }

                try Task.checkCancellation()
                await MainActor.run { self.progress = 1.0 }

                // Notify app that a video was uploaded and Profile should refresh
                NotificationCenter.default.post(name: .videoUploaded, object: nil)
                NotificationCenter.default.post(name: .profileShouldRefresh, object: nil)

                return videoId

            } catch is CancellationError {
                await MainActor.run { self.errorText = "Upload cancelled." }
                // cleanup compressed temp file if any
                if let t = compressedTempURL {
                    try? FileManager.default.removeItem(at: t)
                }
                return nil
            } catch {
                if let t = compressedTempURL {
                    try? FileManager.default.removeItem(at: t)
                }
                await MainActor.run { self.errorText = error.localizedDescription }
                return nil
            }
        }

        currentTask = task
        return await task.value
    }

    // MARK: - Compression helper
    private func compressVideo(inputURL: URL, quality: VideoQuality) async -> URL? {
        let asset = AVAsset(url: inputURL)
        guard let export = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
            return nil
        }
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        return await withCheckedContinuation { continuation in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        Task { @MainActor in self.isUploading = false; self.errorText = "Upload cancelled." }
    }

    func retry() async -> UUID? {
        guard let params = lastParams else { return nil }
        return await uploadVideoFile(fileURL: params.fileURL, caption: params.caption, userId: params.userId)
    }

    func retryInsert() async {
        guard let payload = lastInsertPayload else { return }
        var attempt = 0
        var delayNs: UInt64 = 500_000_000 // 500ms
        while attempt < 3 {
            do {
                print("[Uploader] retryInsert attempting insert for user_id=\(payload.user_id), video_id=\(payload.id)")
                try await insertVideoRow(payload)
                await MainActor.run {
                    self.errorText = nil
                    self.lastInsertPayload = nil
                    self.progress = 1.0
                }
                print("[Uploader] retryInsert succeeded on attempt \(attempt + 1)")
                // Notify UI that finalize succeeded so views can show feedback
                NotificationCenter.default.post(name: .metadataFinalizeSucceeded, object: nil)
                return
            } catch {
                attempt += 1
                print("[Uploader] retryInsert attempt \(attempt) failed: \(error)")
                if attempt >= 3 {
                    await MainActor.run {
                        self.errorText = "Finalize failed: \(error.localizedDescription)"
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: delayNs)
                delayNs = min(delayNs * 2, 5_000_000_000)
            }
        }
    }
}

// Notification used to signal metadata finalize success
extension Notification.Name {
    static let metadataFinalizeSucceeded = Notification.Name("metadataFinalizeSucceeded")
}

