import Foundation

/// Minimal AI client that posts a compact payload to the deployed edge function.
public final class VibeXAIClient {
    public let functionURL: URL
    public let publishableKey: String
    public let storageBucket: String

    public init(functionURL: URL = URL(string: "https://jnkzbfqrwkgfiyxvwrug.supabase.co/functions/v1/vibex-ai-chat")!, publishableKey: String, storageBucket: String = "videos") {
        self.functionURL = functionURL
        self.publishableKey = publishableKey
        self.storageBucket = storageBucket
    }

    public struct Payload: Encodable {
        public let tool: String
        public let message: String
        public let systemPrompt: String?
        public let messages: [ChatPayloadMessage]?
        public let memory: MemoryPayload?
        public let attachments: [VibeXAttachmentPayload]?

        public struct ChatPayloadMessage: Encodable { public let role: String; public let content: String }
        public struct MemoryPayload: Encodable { public let savedStyle: String; public let myVoice: String; public let brandTone: String }
    }

    private func uploadAttachments(_ attachments: [VibeXAttachment]) async throws -> [VibeXAttachmentPayload]? {
        guard !attachments.isEmpty else { return nil }
        guard let host = functionURL.host else { throw URLError(.badURL) }
        let storage = SupabaseStorage(host: host, publishableKey: publishableKey, bucket: storageBucket)
        var payloads: [VibeXAttachmentPayload] = []
        for att in attachments {
            let ext = (att.filename as NSString).pathExtension
            let filenameOnBucket = "\(UUID().uuidString).\(ext.isEmpty ? (att.kind == .video ? "mov" : "jpg") : ext)"
            let contentType = att.kind == .video ? "video/quicktime" : "image/jpeg"
            let url = try await storage.upload(data: att.data, path: filenameOnBucket, contentType: contentType)
            payloads.append(VibeXAttachmentPayload(type: att.kind.rawValue, url: url.absoluteString))
        }
        return payloads
    }

    public func send(tool: VibeXAITool, input: String, history: [VibeXChatMessage], memory: AgentMemory, attachments: [VibeXAttachment]) async throws -> String {
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")

        let recent = history.suffix(12).map { Payload.ChatPayloadMessage(role: $0.role.rawValue, content: $0.text) }
        let mem = Payload.MemoryPayload(savedStyle: memory.savedStyle, myVoice: memory.myVoice, brandTone: memory.brandTone)
        let attachmentPayloads = try await uploadAttachments(attachments)

        let body = Payload(tool: tool.rawValue, message: input, systemPrompt: nil, messages: recent.isEmpty ? nil : recent, memory: mem, attachments: attachmentPayloads)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200...299).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "VibeXAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: raw])
        }

        if let decoded = try? JSONDecoder().decode(VibeXAIResponse.self, from: data), let text = decoded.bestText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return String(data: data, encoding: .utf8) ?? "No response."
    }

    // Overload with optional system prompt
    public func send(tool: VibeXAITool, input: String, history: [VibeXChatMessage], memory: AgentMemory, attachments: [VibeXAttachment], systemPrompt: String?) async throws -> String {
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")

        let recent = history.suffix(12).map { Payload.ChatPayloadMessage(role: $0.role.rawValue, content: $0.text) }
        let mem = Payload.MemoryPayload(savedStyle: memory.savedStyle, myVoice: memory.myVoice, brandTone: memory.brandTone)
        let attachmentPayloads = try await uploadAttachments(attachments)

        let body = Payload(tool: tool.rawValue, message: input, systemPrompt: systemPrompt, messages: recent.isEmpty ? nil : recent, memory: mem, attachments: attachmentPayloads)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200...299).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "VibeXAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: raw])
        }

        if let decoded = try? JSONDecoder().decode(VibeXAIResponse.self, from: data), let text = decoded.bestText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return String(data: data, encoding: .utf8) ?? "No response."
    }

    /// Stream responses from the function (server-side proxy) as UTF-8 chunks.
    /// The stream yields raw string chunks as they arrive; callers should append them to an assistant message.
    public func sendStream(tool: VibeXAITool, input: String, history: [VibeXChatMessage], memory: AgentMemory, attachments: [VibeXAttachment], systemPrompt: String?) async throws -> AsyncThrowingStream<String, Error> {
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let recent = history.suffix(12).map { Payload.ChatPayloadMessage(role: $0.role.rawValue, content: $0.text) }
        let mem = Payload.MemoryPayload(savedStyle: memory.savedStyle, myVoice: memory.myVoice, brandTone: memory.brandTone)
        let attachmentPayloads = try await uploadAttachments(attachments)

        // Create a stream payload with the stream flag
        struct StreamPayload: Encodable {
            let tool: String
            let message: String
            let systemPrompt: String?
            let messages: [Payload.ChatPayloadMessage]?
            let memory: Payload.MemoryPayload
            let attachments: [VibeXAttachmentPayload]?
            let stream: Bool
        }
        
        let body = StreamPayload(
            tool: tool.rawValue,
            message: input,
            systemPrompt: systemPrompt,
            messages: recent.isEmpty ? nil : recent,
            memory: mem,
            attachments: attachmentPayloads,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        let text = "HTTP \(http.statusCode)"
                        continuation.finish(throwing: NSError(domain: "VibeXAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text]))
                        return
                    }

                    var buffer = [UInt8]()
                    for try await byte in byteStream {
                        buffer.append(byte)
                        // Try to decode available bytes to UTF8 string and yield
                        let chunk = String(decoding: buffer, as: UTF8.self)
                        if !chunk.isEmpty {
                            continuation.yield(chunk)
                            buffer.removeAll()
                        }
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
