import SwiftUI
import _PhotosUI_SwiftUI
import Supabase

// Lightweight wrapper kept for backward compatibility.
// Use `VibeXAIChatView` in `vibex/VibeXAIChat/Views` for the full implementation.
@available(*, unavailable, message: "Use VibeXAIChatView instead")
struct LegacyVibexAIChatView: View {
    var body: some View { VibeXAIChatView() }
}
// Use shared UI components from VibeXAIChat/Components/VibeXAIComponents.swift

// MARK: - Preview
#Preview {
    NavigationStack { VibeXAIChatView(initialTool: .chat) }
}

/// Helper that uploads a small test object using the Supabase client (client-only).
/// This replaces the previous Edge Function example and avoids requiring function deployment.
func callPresignUpload(supabase: SupabaseClient) async throws -> Data {
    let bucket = "videos"
    // Build a tiny text object and attempt client-side upload/sign with a preflight check
    let fileData = "test from client".data(using: .utf8)!
    let fileName = "client-presign-test-\(UUID().uuidString).txt"
    let path = "test-uploads/\(fileName)"

    // Preflight: list to confirm bucket reachability with current auth/policies
    do {
        _ = try await supabase.storage
            .from(bucket)
            .list(path: "")
    } catch {
        let msg = error.localizedDescription
        if msg.localizedCaseInsensitiveContains("bucket not found") {
            let userInfo = [NSLocalizedDescriptionKey: "Storage bucket '\(bucket)' was not found. Create it in Supabase Storage or update the bucket name."]
            throw NSError(domain: "Storage", code: 404, userInfo: userInfo)
        }
        if msg.localizedCaseInsensitiveContains("unauthorized") || msg.localizedCaseInsensitiveContains("permission") || msg.localizedCaseInsensitiveContains("forbidden") {
            let userInfo = [NSLocalizedDescriptionKey: "Storage access denied. Ensure the user is authenticated and Storage policies allow access to bucket '\(bucket)'."]
            throw NSError(domain: "Storage", code: 403, userInfo: userInfo)
        }
        // Not fatal for list; continue to attempt upload
    }

    do {
        try await supabase.storage
            .from(bucket)
            .upload(path: path, file: fileData, options: FileOptions(contentType: "text/plain", upsert: false))

        let signed = try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 60 * 60)

        let resp: [String: String] = [
            "path": path,
            "signed_url": signed.absoluteString
        ]
        return try JSONSerialization.data(withJSONObject: resp)
    } catch {
        let msg = error.localizedDescription
        if msg.localizedCaseInsensitiveContains("bucket not found") {
            let userInfo = [NSLocalizedDescriptionKey: "Storage bucket '\(bucket)' was not found. Create it in Supabase Storage or update the bucket name."]
            throw NSError(domain: "Storage", code: 404, userInfo: userInfo)
        }
        if msg.localizedCaseInsensitiveContains("payload too large") || msg.localizedCaseInsensitiveContains("object exceeded") || msg.localizedCaseInsensitiveContains("exceeded") {
            let userInfo = [NSLocalizedDescriptionKey: "Storage upload failed: The object exceeded the allowed size. Check your Storage file size limits and policies."]
            throw NSError(domain: "Storage", code: 413, userInfo: userInfo)
        }
        if msg.localizedCaseInsensitiveContains("unauthorized") || msg.localizedCaseInsensitiveContains("permission") || msg.localizedCaseInsensitiveContains("forbidden") {
            let userInfo = [NSLocalizedDescriptionKey: "Storage access denied. Ensure the user is authenticated and Storage policies allow INSERT and SELECT on bucket '\(bucket)'."]
            throw NSError(domain: "Storage", code: 403, userInfo: userInfo)
        }
        throw error
    }
}

