import SwiftUI
import UIKit
import AVKit
import PhotosUI

// Brand color helpers
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static var vbBackground: Color {
        Color(hex: ThemeManager.shared.isNeon ? "0A0B1D" : "060510")
    }

    static var vbPurple: Color {
        Color(hex: ThemeManager.shared.isNeon ? "7B2FF7" : "5E3ABF")
    }

    static var vbPink: Color {
        Color(hex: ThemeManager.shared.isNeon ? "FF3CAC" : "D24FB0")
    }

    static var vbBlue: Color {
        Color(hex: ThemeManager.shared.isNeon ? "2B8CFF" : "1E6FD8")
    }

    static var vbAccentText: Color { Color(hex: "FFFFFF") }
    static var vbGlow: Color { Color(hex: "FFFFFF1A") }
}


struct UploadHub: View {
    @EnvironmentObject var draftStore: DraftStore
    @EnvironmentObject var auth: AuthManager
    @State private var showUploader = false
    @State private var aiClient = AINetworkClient.shared
    @StateObject private var videoUploader = SupabaseVideoUploader()

    @State private var isProcessing6D = false
    @State private var sixdStatusMessage: String? = nil
    @State private var showPreview = false
    @State private var previewURL: URL? = nil
    @State private var previewCaption: String = "Funny version"
    @State private var showMovieMakerSheet = false
    @State private var notifyMovieMaker = false

    let prefilledURL: URL?

    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                LogoBadge()
                
                Text("Upload Hub")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.vbAccentText)

                Text("Pick a video, get AI-assisted captions, and upload to your feed.")
                    .foregroundColor(.vbAccentText.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Button(action: { showUploader = true }) {
                    HStack(spacing: 12) {
                        LogoBadge(size: 28)
                        Text("Choose Video")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.vbAccentText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.vbPurple, Color.vbPink, Color.vbBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.vbBlue.opacity(0.35), radius: 18, x: 0, y: 8)
                }
                .padding(.horizontal, 36)

                VStack(spacing: 10) {
                    Button(action: { Task { await performFunny6D() } }) {
                        HStack {
                            if isProcessing6D { ProgressView().tint(.white) }
                            Image(systemName: "face.smiling")
                            Text("Make Funny Version")
                        }
                        .foregroundColor(.vbAccentText)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.vbBlue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 36)
                    .disabled(isProcessing6D)

                    MovieMakerComingSoonCard {
                        showMovieMakerSheet = true
                    }

                    if let msg = sixdStatusMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.vbAccentText.opacity(0.9))
                            .padding(.horizontal, 36)
                    }
                }
            }
            .padding(.vertical, 48)
        }
        .onAppear {
            if let u = prefilledURL, previewURL == nil {
                previewURL = u
                showPreview = true
                sixdStatusMessage = "Preview ready"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenUploadPicker"))) { _ in
            // Open the uploader sheet when requested from other views
            showUploader = true
        }
        .sheet(isPresented: $showUploader) {
            SimpleUploadView()
                .environmentObject(draftStore)
                .environmentObject(auth)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showPreview) {
            if let url = previewURL {
                VStack(spacing: 12) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 360)
                        .cornerRadius(12)

                    Text("Preview generated video before upload")
                        .foregroundColor(.vbAccentText)

                    TextEditor(text: $previewCaption)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            previewURL = nil
                            showPreview = false
                            sixdStatusMessage = "Upload cancelled"
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(8)

                        Button(action: { Task { await confirmUploadFromPreview() } }) {
                            HStack {
                                Image(systemName: "arrow.up.doc")
                                Text("Upload to Feed")
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.vbBlue)
                        .cornerRadius(8)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                }
                .padding()
                .preferredColorScheme(.dark)
            } else {
                Text("No preview available")
            }
        }
        .sheet(isPresented: $showMovieMakerSheet) {
            MovieMakerComingSoonSheet(notifyMe: $notifyMovieMaker)
                .preferredColorScheme(.dark)
        }
    }
}

struct LogoBadge: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(Color.vbGlow, lineWidth: 1)
                        .blur(radius: 6)
                )
                .shadow(color: Color.vbBlue.opacity(0.25), radius: 14, x: 0, y: 8)
                .neonGlow()

            Image(systemName: "play.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.48, height: size * 0.48)
                .foregroundColor(.white)
                .shadow(color: Color.vbPink.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
}

extension UploadHub {
    // Perform the full flow: request sixd effect, poll if queued, download result, and upload to feed
    func performFunny6D() async {
        guard !isProcessing6D else { return }
        isProcessing6D = true
        sixdStatusMessage = "Requesting funny effect..."

        do {
            let resp = try await aiClient.generate6DEffect(preset: "funny", options: ["intensity": 0.9])

            // If we have a direct result URL, proceed
            if let resultURLString = resp["resultURL"] as? String, let url = URL(string: resultURLString) {
                sixdStatusMessage = "Downloading result..."
                try await downloadAndUpload(url: url)
                sixdStatusMessage = "Uploaded funny video to feed."
                isProcessing6D = false
                return
            }

            // If job queued, poll
            if let jobId = resp["jobId"] as? String {
                sixdStatusMessage = "Job queued (\(jobId)). Waiting for result..."
                let result = try await aiClient.pollSixdStatus(jobId: jobId)
                if let resultURLString = result["resultURL"] as? String, let url = URL(string: resultURLString) {
                    sixdStatusMessage = "Downloading result..."
                    try await downloadAndUpload(url: url)
                    sixdStatusMessage = "Uploaded funny video to feed."
                    isProcessing6D = false
                    return
                }
            }

            sixdStatusMessage = "No result URL returned from backend."
        } catch {
            sixdStatusMessage = "6D error: \(error.localizedDescription)"
        }

        isProcessing6D = false
    }

    private func downloadAndUpload(url: URL) async throws {
        // download data
        let (data, _) = try await URLSession.shared.data(from: url)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("funny-\(UUID().uuidString).mp4")
        try data.write(to: tmp)

        // Instead of auto-uploading, present a preview to the user with an editable caption
        previewURL = tmp
        previewCaption = "Funny version"
        showPreview = true
    }

    // Called from preview sheet to upload the confirmed video
    func confirmUploadFromPreview() async {
        guard let url = previewURL else { return }
        guard let userId = auth.currentUserId else {
            await MainActor.run { sixdStatusMessage = "Not signed in" }
            return
        }

        await MainActor.run {
            isProcessing6D = true
            sixdStatusMessage = "Uploading to feed..."
        }

        let videoId = await videoUploader.uploadVideoFile(fileURL: url, caption: previewCaption, userId: userId)

        if let id = videoId {
            await MainActor.run {
                sixdStatusMessage = "Upload complete. Publishing…"
            }
            // Notify the app to refresh any feed/list that depends on newly uploaded videos
            NotificationCenter.default.post(name: .init("vb.feedShouldRefresh"), object: nil, userInfo: ["videoId": id.uuidString])

            await MainActor.run {
                sixdStatusMessage = "Uploaded funny video to feed."
            }
        } else {
            let msg = videoUploader.errorText ?? "unknown"
            await MainActor.run {
                sixdStatusMessage = "Upload failed: \(msg)"
            }
        }

        // cleanup and dismiss preview
        await MainActor.run {
            previewURL = nil
            showPreview = false
            isProcessing6D = false
        }
    }
}


// Duplicate `SimpleUploadView` was removed; use the single definition in SimpleUploadView.swift

struct VXProgressRing: View {
    let progress: Double // 0...1
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.001, min(1.0, progress)))
                .stroke(
                    LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.vbBlue.opacity(0.35), radius: 8, x: 0, y: 4)

            Text("VX")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .frame(width: 72, height: 72)
    }
}

struct MovieMakerComingSoonCard: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [.purple, .pink, .blue],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                        .shadow(color: .purple.opacity(0.25), radius: 14)

                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Make a Movie")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("COMING SOON")
                            .font(.caption2.weight(.heavy))
                            .foregroundColor(.white)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }

                    Text("Create 60s shorts or full 1-hour movies with AI — then publish & earn on VibeX.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct MovieMakerComingSoonSheet: View {
    @Binding var notifyMe: Bool
    @State private var showEditorPreview = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .pink, .blue],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 54, height: 54)
                                .shadow(color: .pink.opacity(0.25), radius: 14)
                            Image(systemName: "film.stack.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 22, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("VibeX AI Movie Maker")
                                .font(.title2.weight(.heavy))
                                .foregroundColor(.white)

                            Text("Coming Soon • Create • Edit • Publish • Earn")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.65))
                        }

                        Spacer()
                    }
                    .padding(.top, 10)

                    // Main info
                    InfoCard(title: "Lengths you can create") {
                        Bullet("60s Movie Short (fast creation)")
                        Bullet("1-Hour Movie (full story + scenes)")
                        Bullet("Choose: Action, Comedy, Horror, Drama, Anime, etc.")
                    }

                    InfoCard(title: "How AI works (the flow)") {
                        Bullet("You type: characters + plot + style")
                        Bullet("AI generates: scenes + dialogue + shots")
                        Bullet("You edit in the VibeX Movie Editor")
                        Bullet("Publish to VibeX Movies")
                    }

                    InfoCard(title: "How you make money on VibeX") {
                        Bullet("Ads / revenue share on views (when enabled)")
                        Bullet("Sell access (rent/buy) or creator subscription add-on")
                        Bullet("Tips / gifts during premieres")
                        Bullet("Brand deals & sponsored placements (future)")
                        Text("All earnings features will roll out with creator verification + payouts.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 6)
                    }

                    // Editor preview (locked)
                    InfoCard(title: "Editor Screen (preview)") {
                        Text("When this launches, tapping “Make a Movie” will open the editor where you can:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Bullet("Trim / reorder scenes")
                        Bullet("Change music, captions, subtitles")
                        Bullet("Replace shots with new AI shots")
                        Bullet("Export & publish to your profile + Movies tab")

                        Button {
                            showEditorPreview = true
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Preview the Editor UI")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [.purple, .pink, .blue],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: .purple.opacity(0.22), radius: 14)
                        }
                        .buttonStyle(.plain)
                    }

                    // Notify me
                    InfoCard(title: "Get notified") {
                        Toggle(isOn: $notifyMe) {
                            Text("Notify me when Movie Maker drops")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .tint(.purple)

                        Text("For now this is local UI. Later we’ll connect it to real notifications.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 6)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showEditorPreview) {
            MovieEditorPreviewScreen()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Reusable pieces
private struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            content
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LinearGradient(colors: [.purple, .pink, .blue],
                                                startPoint: .leading, endPoint: .trailing))
                .padding(.top, 1)
            Text(text)
                .foregroundColor(.white.opacity(0.86))
                .font(.subheadline)
        }
    }
}

