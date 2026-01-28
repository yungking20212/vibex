import Foundation

/// Minimal Supabase Storage uploader for public buckets.
/// NOTE: For private buckets use a server presign approach instead of exposing keys client-side.
struct SupabaseStorage {
    let host: String // e.g. jnkzbfqrwkgfiyxvwrug.supabase.co
    let publishableKey: String
    let bucket: String

    init(host: String, publishableKey: String, bucket: String = "videos") {
        self.host = host
        self.publishableKey = publishableKey
        self.bucket = bucket
    }

    /// Uploads data to `PUT /storage/v1/object/{bucket}/{path}` and returns the public object URL.
    func upload(data: Data, path: String, contentType: String) async throws -> URL {
        let base = "https://\(host)"
        guard let uploadURL = URL(string: "\(base)/storage/v1/object/\(bucket)/\(path)") else { throw URLError(.badURL) }

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        req.setValue(publishableKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let publicURL = URL(string: "\(base)/storage/v1/object/public/\(bucket)/\(path)") else { throw URLError(.badURL) }
        return publicURL
    }
}
