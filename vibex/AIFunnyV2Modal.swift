import SwiftUI

struct AIFunnyV2Modal: View {
    @State private var selectedStyle: String = "Meme Style"
    @State private var intensity: Double = 0.8
    @State private var speed: Double = 1.0
    @State private var sourceURL: String = ""
    
    @State private var isLaunching: Bool = false
    @State private var resultURL: String?
    @State private var jobId: String?
    @State private var errorMessage: String?
    
    @State private var showUpload = false
    @State private var uploadURL: URL? = nil
    
    let onClose: () -> Void
    
    private let styles = ["Meme Style", "Face Warp", "Caption Overlay"]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.15, green: 0.15, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("AI Funny Generator")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                Picker("Style", selection: $selectedStyle) {
                    ForEach(styles, id: \.self) { style in
                        Text(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .background(GlassBackground(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Group {
                    VStack(alignment: .leading) {
                        Text("Intensity \(String(format: "%.2f", intensity))")
                            .foregroundColor(.white)
                        Slider(value: $intensity, in: 0...1)
                            .tint(.blue)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("Speed \(String(format: "%.2fx", speed))")
                            .foregroundColor(.white)
                        Slider(value: $speed, in: 0.5...2.0)
                            .tint(.blue)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("Source Video URL")
                            .foregroundColor(.white)
                        TextField("https://...", text: $sourceURL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .padding(10)
                            .background(GlassBackground(cornerRadius: 12))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                }
                
                Button {
                    Task {
                        await launch()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue)
                            .frame(height: 48)
                        if isLaunching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Launch")
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                }
                .padding(.horizontal)
                .disabled(isLaunching || sourceURL.isEmpty)
                
                Spacer()
                
                if let resultURL = resultURL {
                    LocalGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result URL:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(resultURL)
                                .font(.footnote)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = resultURL
                                    } label: {
                                        Label("Copy URL", systemImage: "doc.on.doc")
                                    }
                                }
                            
                            Button {
                                if let url = URL(string: resultURL) {
                                    uploadURL = url
                                    showUpload = true
                                }
                            } label: {
                                Label("Open in Upload", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                } else if let jobId = jobId {
                    LocalGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Job ID:")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(jobId)
                                .font(.footnote)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
                
                Button {
                    onClose()
                } label: {
                    Text("Close")
                        .foregroundColor(.white)
                        .underline()
                        .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showUpload) {
            UploadHubContainer(prefilledURL: uploadURL)
        }
    }
    
    func launch() async {
        isLaunching = true
        resultURL = nil
        jobId = nil
        errorMessage = nil
        
        let client = AIFunnyClient()
        
        do {
            let response = try await client.generate(
                style: selectedStyle,
                intensity: intensity,
                speed: speed,
                sourceVideoURL: sourceURL
            )
            
            if let resURL = response.resultURL {
                resultURL = resURL
            } else if let jId = response.jobId {
                jobId = jId
            } else {
                errorMessage = "Unknown response from server."
            }
        } catch {
            errorMessage = "Failed to launch: \(error.localizedDescription)"
        }
        
        isLaunching = false
    }
}

struct AIFunnyResponse: Codable {
    var resultURL: String?
    var jobId: String?
    var message: String?
}

final class AIFunnyClient {
    // TODO: Replace with your actual Supabase project URL and anon key
    private let supabaseURL = URL(string: "https://YOUR-PROJECT.supabase.co")!
    private let supabaseAnonKey = "YOUR-ANON-KEY"
    // TODO: Confirm the function name for AI Funny (e.g., "svid" or your custom name)
    private let functionName = "svid"

    struct RequestBody: Codable {
        let style: String
        let intensity: Double
        let speed: Double
        let sourceVideoURL: String
    }

    func generate(style: String, intensity: Double, speed: Double, sourceVideoURL: String) async throws -> AIFunnyResponse {
        guard let url = URL(string: "/functions/v1/\(functionName)", relativeTo: supabaseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let payload = RequestBody(style: style, intensity: intensity, speed: speed, sourceVideoURL: sourceVideoURL)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        // Attempt to decode even on non-2xx to surface backend message
        let decoded = try? JSONDecoder().decode(AIFunnyResponse.self, from: data)
        if (200..<300).contains(http.statusCode) {
            if let decoded = decoded { return decoded }
            // Fallback: try to parse minimal success
            return AIFunnyResponse(resultURL: nil, jobId: nil, message: nil)
        } else {
            let msg = decoded?.message ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "AIFunnyClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}

struct LocalGlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(4)
    }
}

struct GlassBackground: View {
    var cornerRadius: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

#Preview {
    AIFunnyV2Modal(onClose: {})
}
