import Foundation

@MainActor
final class AINetworkClient {
    static let shared = AINetworkClient()

    /// Configure these with your real endpoint and token.
    /// These values are persisted to UserDefaults keys `ai_base_url` and `ai_bearer_token`.
    var baseURL: URL?
    var bearerToken: String?
    /// Optional Supabase/Edge Functions API key (anon/public key). If set,
    /// the client will send it as `apikey` header as well as `Authorization`.
    var apiKey: String?
    /// Name of the transform function (defaults to `sixd`). Configure to `svid` if your function is named that.
    var transformFunctionName: String = "sixd"

    private init() {
        if let s = UserDefaults.standard.string(forKey: "ai_base_url") {
            baseURL = URL(string: s)
        }
        bearerToken = UserDefaults.standard.string(forKey: "ai_bearer_token")
    }

    /// Configure at runtime (e.g. from settings). Passing nil will clear the stored value.
    func configure(baseURLString: String?, bearerToken: String?) {
        if let s = baseURLString, let url = URL(string: s) {
            self.baseURL = url
            UserDefaults.standard.set(s, forKey: "ai_base_url")
        } else {
            self.baseURL = nil
            UserDefaults.standard.removeObject(forKey: "ai_base_url")
        }

        self.bearerToken = bearerToken
        if let token = bearerToken {
            UserDefaults.standard.set(token, forKey: "ai_bearer_token")
        } else {
            UserDefaults.standard.removeObject(forKey: "ai_bearer_token")
        }
    }

    /// Convenience configure for Supabase-hosted functions. If you have a
    /// project id like `jnkzbfqrwkgfiyxvwrug`, call
    /// `configureSupabase(project: "jnkzbfqrwkgfiyxvwrug", apiKey: "...")`.
    /// This will allow the client to try the functions subdomain
    /// `https://<project>.functions.supabase.co` as a candidate endpoint.
    func configureSupabase(project: String?, apiKey: String?) {
        if let p = project, !p.isEmpty {
            // functions subdomain
            if URL(string: "https://\(p).functions.supabase.co") != nil {
                // if baseURL is nil, set to project root
                if baseURL == nil {
                    baseURL = URL(string: "https://\(p).supabase.co")
                    UserDefaults.standard.set(baseURL?.absoluteString, forKey: "ai_base_url")
                }
                // persist apiKey
                self.apiKey = apiKey
                if let k = apiKey { UserDefaults.standard.set(k, forKey: "ai_api_key") }
                else { UserDefaults.standard.removeObject(forKey: "ai_api_key") }
            }
        } else {
            self.apiKey = apiKey
            if let k = apiKey { UserDefaults.standard.set(k, forKey: "ai_api_key") }
            else { UserDefaults.standard.removeObject(forKey: "ai_api_key") }
        }
        // restore transform function name if previously saved
        if let fn = UserDefaults.standard.string(forKey: "ai_transform_fn") {
            transformFunctionName = fn
        }
    }

    func configureTransformFunction(name: String?) {
        if let n = name, !n.isEmpty {
            transformFunctionName = n
            UserDefaults.standard.set(n, forKey: "ai_transform_fn")
        } else {
            transformFunctionName = "sixd"
            UserDefaults.standard.removeObject(forKey: "ai_transform_fn")
        }
    }

    enum ClientError: Error {
        case noBaseURL
        case invalidResponse
        case serverError(String)
    }

    /// Build and attempt requests against a set of likely candidate URLs.
    private func performRequest(path: String, body: Data) async throws -> (Data, HTTPURLResponse) {
        // Build candidate URLs to try in order
        var candidates: [URL] = []

        if let base = baseURL {
            // If this looks like a Supabase project and we have an apiKey, prefer the functions subdomain
            if let host = base.host, host.hasSuffix("supabase.co") {
                let project = host.replacingOccurrences(of: ".supabase.co", with: "")
                if !project.isEmpty, let funcBase = URL(string: "https://\(project).functions.supabase.co") {
                    // If path maps to ai/<fn> and we have a configured transform function, prefer that function on the subdomain
                    let candidatePath = path.replacingOccurrences(of: "ai/\(transformFunctionName)", with: "\(transformFunctionName)")
                    candidates.append(funcBase.appendingPathComponent(candidatePath))
                }
                // also try functions/v1 path on project root
                if let funcs = URL(string: base.absoluteString)?.appendingPathComponent("functions/v1/") {
                    candidates.append(funcs.appendingPathComponent(transformFunctionName))
                }
            }

            // default candidate: base + provided path
            candidates.append(base.appendingPathComponent(path))
        }

        // If a functions subdomain is likely (project.functions.supabase.co), try that too
        if let base = baseURL, let host = base.host, host.hasSuffix("supabase.co") {
            let project = host.replacingOccurrences(of: ".supabase.co", with: "")
            if !project.isEmpty, let funcBase = URL(string: "https://\(project).functions.supabase.co") {
                // if incoming path is ai/<fn>
                let comps = path.split(separator: "/")
                if comps.count >= 2 {
                    let fn = String(comps[1])
                    candidates.append(funcBase.appendingPathComponent(fn))
                } else {
                    candidates.append(funcBase.appendingPathComponent(path))
                }
            }
        }

        // Deduplicate candidates
        var seen: Set<String> = []
        candidates = candidates.filter { url in
            let s = url.absoluteString
            if seen.contains(s) { return false }
            seen.insert(s)
            return true
        }

        var lastError: Error? = nil
        for url in candidates {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = bearerToken {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            if let k = apiKey {
                req.setValue(k, forHTTPHeaderField: "apikey")
            }
            req.httpBody = body

            do {
                let (d, r) = try await URLSession.shared.data(for: req)
                if let http = r as? HTTPURLResponse, 200..<300 ~= http.statusCode {
                    return (d, http)
                } else {
                    lastError = ClientError.invalidResponse
                    continue
                }
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? ClientError.noBaseURL
    }

    func suggestCaption(prompt: String, context: [String: Any]? = nil) async throws -> String {
        let payload: [String: Any] = ["prompt": prompt, "context": context ?? [:]]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (d, _) = try await performRequest(path: "ai/suggestCaption", body: data)
        let json = try JSONSerialization.jsonObject(with: d, options: [])
        if let dict = json as? [String: Any], let caption = dict["caption"] as? String {
            return caption
        }
        throw ClientError.invalidResponse
    }

    /// Try to fetch multiple caption suggestions in a single call. If the backend
    /// does not implement `ai/suggestCaptions`, fall back to repeated single calls.
    func suggestCaptions(prompt: String, count: Int = 3, context: [String: Any]? = nil) async throws -> [String] {
        // Try batch endpoint first
        do {
            let payload: [String: Any] = ["prompt": prompt, "count": count, "context": context ?? [:]]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (d, _) = try await performRequest(path: "ai/suggestCaptions", body: data)
            let json = try JSONSerialization.jsonObject(with: d, options: [])
            if let dict = json as? [String: Any], let captions = dict["captions"] as? [String] {
                return captions
            }
            // fall through to fallback
        } catch {
            // Ignore and try fallback
        }

        // Fallback: call the single caption endpoint multiple times
        var results: [String] = []
        for i in 0..<count {
            let promptVariant = "\(prompt) (option \(i+1))"
            let s = try await suggestCaption(prompt: promptVariant, context: context)
            results.append(s)
        }
        return results
    }

    func generateHashtags(text: String, count: Int = 5) async throws -> [String] {
        let payload: [String: Any] = ["text": text, "count": count]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (d, _) = try await performRequest(path: "ai/hashtags", body: data)
        let json = try JSONSerialization.jsonObject(with: d, options: [])
        if let dict = json as? [String: Any], let tags = dict["hashtags"] as? [String] {
            return tags
        }
        throw ClientError.invalidResponse
    }

    func titleIdeas(text: String, count: Int = 5) async throws -> [String] {
        let payload: [String: Any] = ["text": text, "count": count]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let (d, _) = try await performRequest(path: "ai/titleIdeas", body: data)
        let json = try JSONSerialization.jsonObject(with: d, options: [])
        if let dict = json as? [String: Any], let titles = dict["titles"] as? [String] {
            return titles
        }
        throw ClientError.invalidResponse
    }
    
    /// Generate or apply a 6D effect using the backend. The backend should accept a JSON body
    /// like { "preset": "Depth Glow", "options": { ... } } and return a JSON with a job id
    /// or a result URL, e.g. { "jobId": "..." } or { "resultURL": "https://..." }.
    func generate6DEffect(preset: String, options: [String: Any]? = nil) async throws -> [String: Any] {
        // Note: function name must start with a letter for Supabase functions.
        // We use "sixd" as the function name and the client will try
        // /ai/sixd -> /functions/v1/sixd -> https://<project>.functions.supabase.co/sixd
        let payload: [String: Any] = [
            "preset": preset,
            "options": options ?? [:]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        // Use configured transform function name
        let fn = transformFunctionName
        let path = "ai/\(fn)"
        let (d, _) = try await performRequest(path: path, body: data)
        let json = try JSONSerialization.jsonObject(with: d, options: [])
        if let dict = json as? [String: Any] {
            return dict
        }
        throw ClientError.invalidResponse
    }

    /// Polls the backend for a job result. Tries GET requests against likely
    /// candidate status endpoints: `ai/sixd/status/<jobId>`, `functions/v1/sixd/status/<jobId>`,
    /// and the functions subdomain `/sixd/status/<jobId>`.
    func pollSixdStatus(jobId: String, interval: TimeInterval = 3.0, timeout: TimeInterval = 120.0) async throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeout)

        func candidateStatusURLs() -> [URL] {
            var urls: [URL] = []
            if let base = baseURL {
                urls.append(base.appendingPathComponent("ai/sixd/status/") .appendingPathComponent(jobId))
                if let host = base.host, host.hasSuffix("supabase.co") {
                    if let funcs = URL(string: base.absoluteString)?.appendingPathComponent("functions/v1/") {
                        urls.append(funcs.appendingPathComponent("sixd/status/").appendingPathComponent(jobId))
                    }
                }
            }
            if let base = baseURL, let host = base.host, host.hasSuffix("supabase.co") {
                let project = host.replacingOccurrences(of: ".supabase.co", with: "")
                if !project.isEmpty, let funcBase = URL(string: "https://\(project).functions.supabase.co") {
                    urls.append(funcBase.appendingPathComponent("sixd/status/").appendingPathComponent(jobId))
                }
            }
            return urls
        }

        var attempt = 0
        while Date() < deadline {
            attempt += 1
            for url in candidateStatusURLs() {
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                if let token = bearerToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                if let k = apiKey { req.setValue(k, forHTTPHeaderField: "apikey") }

                do {
                    let (d, r) = try await URLSession.shared.data(for: req)
                    if let http = r as? HTTPURLResponse, 200..<300 ~= http.statusCode {
                        var responseData = d

                        // Demo behavior: after a few attempts, try the same candidate with ?ready=1
                        if attempt >= 3 {
                            if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                                var readyComps = comps
                                var qs = readyComps.queryItems ?? []
                                qs.append(URLQueryItem(name: "ready", value: "1"))
                                readyComps.queryItems = qs
                                if let readyURL = readyComps.url {
                                    var readyReq = URLRequest(url: readyURL)
                                    readyReq.httpMethod = "GET"
                                    if let token = bearerToken { readyReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                                    if let k = apiKey { readyReq.setValue(k, forHTTPHeaderField: "apikey") }
                                    do {
                                        let (rd, rr) = try await URLSession.shared.data(for: readyReq)
                                        if let rh = rr as? HTTPURLResponse, 200..<300 ~= rh.statusCode {
                                            responseData = rd
                                        }
                                    } catch {
                                        // ignore
                                    }
                                }
                            }
                        }

                        let json = try JSONSerialization.jsonObject(with: responseData, options: [])
                        if let dict = json as? [String: Any] {
                            if dict["resultURL"] != nil || (dict["status"] as? String) == "completed" {
                                return dict
                            }
                        }
                    }
                } catch {
                    // ignore and try next candidate
                }
            }

            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        throw ClientError.serverError("Timeout waiting for sixd job result")
    }
}
