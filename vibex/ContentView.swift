//
//  ContentView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI
import AVKit
import PhotosUI
import UIKit
import Auth

struct UserProfile: Identifiable, Hashable {
    let id: UUID
    let username: String
    let display_name: String?
    let bio: String?
}

// Generate a thumbnail image from a remote or local video URL by extracting a frame.
private func generateFrameThumbnail(from url: URL) async -> UIImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 720, height: 1280)

    let time = CMTime(seconds: 0.8, preferredTimescale: 600)
    return await withCheckedContinuation { cont in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cg = try generator.copyCGImage(at: time, actualTime: nil)
                let ui = UIImage(cgImage: cg)
                cont.resume(returning: ui)
            } catch {
                cont.resume(returning: nil)
            }
        }
    }
}

// Expose Tab selection via Environment using a reference type wrapper
final class TabSelectionBox {
    var binding: Binding<AppShellView.Tab>
    init(_ binding: Binding<AppShellView.Tab>) { self.binding = binding }
}

private struct TabSelectionKey: EnvironmentKey {
    static let defaultValue: TabSelectionBox? = nil
}

extension EnvironmentValues {
    var tabSelection: TabSelectionBox? {
        get { self[TabSelectionKey.self] }
        set { self[TabSelectionKey.self] = newValue }
    }
}

extension Notification.Name {
    static let videoUploaded = Notification.Name("VideoUploaded")
    static let profileShouldRefresh = Notification.Name("ProfileShouldRefresh")
    static let localLikeToggled = Notification.Name("LocalLikeToggled")
    static let localViewCounted = Notification.Name("LocalViewCounted")
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            if !auth.hasBootstrapped {
                NextGenStartupLoadingView()
            } else if auth.session == nil {
                LandingWelcomeView()
            } else {
                AppShellView()
            }
        }
        .onOpenURL { url in
            handleIncoming(url: url)
        }
    }
    
    private func handleIncoming(url: URL) {
        guard url.host == "vibex-dlam8go0k-prnhubstudio.vercel.app" else { return }
        let comps = url.pathComponents // ["/", "u", "username"]
        if comps.count >= 3, comps[1] == "u" {
            let username = comps[2]
            NotificationCenter.default.post(name: .init("DeepLinkProfile"), object: nil, userInfo: ["username": username])
        }
    }
}

// MARK: - Landing Welcome View (Marketing-style)
struct LandingWelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tabSelection) private var tabSelection

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.vbBackground, Color.vbPurple.opacity(0.35), Color.vbBlue.opacity(0.35), Color.vbBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Hero
                    VStack(spacing: 12) {
                        Text("Welcome to PRNHub")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .neonGlow(intensity: 0.9, spread: 1.0)
                        Text("Discover, create, and share amazing content")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)

                    // App Store style button (placeholder action)
                    Button {
                        // TODO: Wire to App Store URL or Auth flow
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 18, weight: .bold))
                            Text("Download on the App Store")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)

                    // Feature cards
                    VStack(spacing: 16) {
                        FeatureCard(icon: "paintbrush.fill", title: "Create", subtitle: "Express yourself with powerful creative tools")
                        FeatureCard(icon: "sparkles", title: "Discover", subtitle: "Find content tailored to your interests")
                        FeatureCard(icon: "person.2.fill", title: "Connect", subtitle: "Build your community and engage with fans")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
        }
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.primaryNeon)
                    .frame(width: 42, height: 42)
                    .neonGlow(intensity: 0.9, spread: 1.0)
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Next-Gen Startup Loading Screen
struct NextGenStartupLoadingView: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var progress: CGFloat = 0.0
    @State private var dotsPhase: Int = 0
    @Namespace private var glassNamespace
    
    var body: some View {
        ZStack {
            // Animated gradient background (brand)
            LinearGradient(
                colors: [
                    Color.vbBackground,
                    Color.vbPurple.opacity(0.20),
                    Color.vbBlue.opacity(0.20),
                    Color.vbBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GlassEffectContainer(spacing: 40.0) {
                VStack(spacing: 48) {
                    // Animated logo/icon
                    ZStack {
                        // Rotating neon ring
                        Circle()
                            .stroke(
                                LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 4
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(rotationAngle))
                            .opacity(glowOpacity)
                            .neonGlow(intensity: 1.0, spread: 1.2)

                        // Bloom core with layered glass
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 110, height: 110)
                            .scaleEffect(pulseScale)
                            .glassEffect(.regular.tint(.purple).interactive(), in: .circle)
                            .neonGlow(intensity: 0.9, spread: 1.0)

                        // Composite app mark
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryNeon)
                                .frame(width: 62, height: 62)
                                .blur(radius: 0.3)

                            Image(systemName: "sparkles")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: Color.white.opacity(0.18), radius: 6, x: 0, y: 2)
                        }
                        .symbolEffect(.pulse)
                    }
                    .glassEffectID("logoIcon", in: glassNamespace)
                    
                    // Brand name with glass background
                    VStack(spacing: 12) {
                        Text("VibeX")
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient.primaryNeon)
                            .neonGlow(intensity: 1.0, spread: 1.1)

                        Text("Next‑Gen Social — Create the Vibe")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.78))

                        // Shimmering progress bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient.primaryNeon)
                                .frame(width: max(36, progress * 240), height: 12)
                                .mask(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: Color.vbBlue.opacity(0.18), radius: 8, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                                )
                                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: progress)
                        }
                        .frame(width: 260)

                        // Loading dots
                        HStack(spacing: 6) {
                            ForEach(0..<3) { idx in
                                Circle()
                                    .fill(Color.white.opacity(dotsPhase % 3 == idx ? 0.95 : 0.28))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(dotsPhase % 3 == idx ? 1.05 : 0.9)
                                    .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(idx) * 0.12), value: dotsPhase)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 40)
                    .glassEffect(.regular, in: .rect(cornerRadius: 32))
                    .glassEffectID("brandCard", in: glassNamespace)
                }
            }
        }
        .onAppear {
            startAnimations()
            // Kick off progress + dot animations
            withAnimation { progress = 0.38 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { progress = 0.76 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { progress = 1.0 }
            }
            // Dot phase timer
            Task {
                while true {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    dotsPhase += 1
                }
            }
        }
    }
    
    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulsing effect
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        // Glow pulsing
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
        }
    }
}

// MARK: - App Shell View (Main Tab Navigation)

private extension VibeXAIClient {
    enum PublishableKeyProvider {
        // WARNING: Replace this with a secure key retrieval (e.g., from Info.plist, Secrets, or remote config)
        static var defaultKey: String { "DEVELOPMENT_KEY" }
    }
}

struct AppShellView: View {
    @State private var selectedTab: Tab = .feed
    
//    private struct TabSelectionKey: EnvironmentKey {
//        static let defaultValue: Binding<Tab>? = nil
//    }
//    
//    extension EnvironmentValues {
//        var tabSelection: Binding<AppShellView.Tab>? {
//            get { self[TabSelectionKey.self] }
//            set { self[TabSelectionKey.self] = newValue }
//        }
//    }
    
    enum Tab: String, CaseIterable {
        case feed = "Feed"
        case upload = "Upload"
        case discover = "Discover"
        case profile = "Profile"
        case aiHub = "Vibex AI"
        // Removed notifications case
        
        var icon: String {
            switch self {
            case .feed: return "play.rectangle.fill"
            case .upload: return "plus.circle.fill"
            case .discover: return "magnifyingglass.circle.fill"
            case .profile: return "person.crop.circle.fill"
            case .aiHub: return "sparkles"
            }
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.86), Color.black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag(Tab.feed)
                    .tabItem {
                        Label(Tab.feed.rawValue, systemImage: Tab.feed.icon)
                    }
                
                UploadHub(prefilledURL: nil)
                    .tag(Tab.upload)
                    .tabItem {
                        Label(Tab.upload.rawValue, systemImage: Tab.upload.icon)
                    }
                
                DiscoverView()
                    .tag(Tab.discover)
                    .tabItem {
                        Label(Tab.discover.rawValue, systemImage: Tab.discover.icon)
                    }
                
                NextGenProfileView()
                    .tag(Tab.profile)
                    .tabItem {
                        Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                    }
                
                // TODO: Inject a real publishable key via secure configuration.
                // Using a placeholder provider to avoid editor placeholder compile error.
                VibexAIChatScreenV3(
                    viewModel: VibeXAIChatViewModel(
                        client: VibeXAIClient(publishableKey: VibeXAIClient.PublishableKeyProvider.defaultKey)
                    )
                )
                    .tag(Tab.aiHub)
                    .tabItem {
                        Label(Tab.aiHub.rawValue, systemImage: Tab.aiHub.icon)
                    }
                
                // Removed notifications tab item
            }
            .environment(\.tabSelection, TabSelectionBox($selectedTab))
            .tint(.white)
            .onReceive(NotificationCenter.default.publisher(for: .init("DeepLinkProfile"))) { note in
                if let username = note.userInfo?["username"] as? String {
                    // Switch to Profile tab immediately
                    selectedTab = .profile
                    // Optionally, post a follow-up notification with the username if Profile needs it
                    NotificationCenter.default.post(name: .init("DeepLinkProfileUsernameReady"), object: nil, userInfo: ["username": username])
                }
            }
        }
    }
}

// MARK: - Feed View (Vertical Video Scroll)

struct FeedView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var currentIndex = 0
    @State private var videos: [VideoPost] = []
    @State private var isLoading = false
    
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    @State private var offset: Int = 0
    @State private var feedErrorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            if let error = feedErrorMessage {
                GlassErrorCard(
                    title: "We couldn’t load your feed.",
                    message: error,
                    retryAction: { Task { await reloadFeedFromStart() } }
                )
                .padding()
            } else if videos.isEmpty {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "video.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No videos yet")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                        Button(action: {
                            Task { await reloadFeedFromStart() }
                        }) {
                            Text("Refresh")
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        VideoPlayerView(video: video, isActive: index == currentIndex)
                            .tag(index)
                            .onAppear {
                                // Prefetch next page when near end
                                if index >= videos.count - 2 {
                                    Task { await loadMoreIfNeeded() }
                                }
                                // Lightweight prefetch stub for next item (extend as needed)
                                prefetchNextItem(from: index)
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _, newIndex in
                    // Trigger pagination when user swipes near the end
                    if newIndex >= videos.count - 2 {
                        Task { await loadMoreIfNeeded() }
                    }
                }

                // Bottom loading indicator for pagination
                if isLoadingMore {
                    VStack {
                        Spacer()
                        ProgressView().tint(.white)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .task {
            await reloadFeedFromStart()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoUploaded)) { _ in
            Task { await reloadFeedFromStart() }
        }
    }
    
    private func reloadFeedFromStart() async {
        feedErrorMessage = nil
        isLoading = true
        isLoadingMore = false
        canLoadMore = true
        offset = 0
        defer { isLoading = false }
        do {
            let page = try await service.fetchFeed(limit: 20, offset: 0)
            videos = page
            currentIndex = 0
            offset = videos.count
            feedErrorMessage = nil
        } catch {
            feedErrorMessage = "Something went wrong while loading your feed. Please try again.\n\nDetails: \(error.localizedDescription)"
            print("Error loading videos: \(error)")
        }
    }

    private func loadMoreIfNeeded() async {
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let more = try await service.fetchFeed(limit: 20, offset: offset)
            if more.isEmpty {
                canLoadMore = false
            } else {
                videos.append(contentsOf: more)
                offset += more.count
            }
        } catch {
            // Don’t block future attempts entirely; surface a soft error.
            print("Error loading more videos: \(error)")
        }
    }

    private func prefetchNextItem(from index: Int) {
        let nextIndex = index + 1
        guard nextIndex < videos.count, let url = URL(string: videos[nextIndex].videoURL) else { return }
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            // Primed for playback; nothing else needed here.
        }
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    @EnvironmentObject var service: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    let video: VideoPost
    let isActive: Bool
    @State private var isLiked = false
    @State private var player: AVPlayer? = nil
    @State private var isMuted: Bool = false
    
    @State private var previewUser: UserProfile? = nil
    @State private var avatarURLString: String? = nil
    @State private var isLoadingAvatar: Bool = false
    
    @State private var localLikes: Int = 0
    @State private var showComments: Bool = false
    
    var body: some View {
        ZStack {
            if let url = URL(string: video.videoURL) {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        // Only rebuild the player if URL changed or not set
                        if (player?.currentItem?.asset as? AVURLAsset)?.url != url {
                            let item = AVPlayerItem(url: url)
                            player = AVPlayer(playerItem: item)
                            player?.actionAtItemEnd = .none

                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: item,
                                queue: .main
                            ) { _ in
                                player?.seek(to: .zero)
                                player?.play()
                            }
                        }

                        // Give the pipeline a moment, then configure audio + play
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            do {
                                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                                try AVAudioSession.sharedInstance().setActive(true)
                            } catch {
                                print("Audio session error: \(error)")
                            }
                            player?.isMuted = false
                            player?.play()
                            
                            Task {
                                await incrementViewCount()
                            }
                        }
                    }
                    .onDisappear {
                        player?.pause()
                        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                    }
                    .onChange(of: isActive) { _, active in
                        if active {
                            player?.play()
                        } else {
                            player?.pause()
                        }
                    }
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.vbPurple.opacity(0.28), Color.vbBlue.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Video info overlay
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Left side - video info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            // Creator avatar placeholder (wire real avatar URL via VideoPost when available)
                            ZStack {
                                if let urlString = avatarURLString, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            Circle().fill(Color.white.opacity(0.10))
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Circle().fill(Color.white.opacity(0.10))
                                        @unknown default:
                                            Circle().fill(Color.white.opacity(0.10))
                                        }
                                    }
                                } else {
                                    Circle().fill(Color.white.opacity(0.10))
                                        .overlay(
                                            Text(String(video.username.prefix(1)).uppercased())
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

                            // Tappable username to show preview
                            Button {
                                presentUserPreview(username: video.username)
                            } label: {
                                Text(video.username)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)

                            Spacer(minLength: 0)
                        }

                        Text(video.caption ?? "")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Right side - mute + action buttons pinned to trailing
                    VStack(spacing: 16) {
                        // Mute/unmute button
                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        // Actions
                        Button(action: {
                            Task { await toggleLikeOptimistic() }
                        }) {
                            ActionButton(icon: isLiked ? "heart.fill" : "heart", count: localLikes)
                                .foregroundColor(isLiked ? .red : .white)
                        }
                        .buttonStyle(.plain)

                        Button { showComments = true } label: {
                            ActionButton(icon: "bubble.right.fill", count: video.comments)
                        }
                        .buttonStyle(.plain)

                        ActionButton(icon: "paperplane.fill", count: nil)

                        ActionButton(icon: "ellipsis", count: nil)

                        Button {
                            if let url = URL(string: video.videoURL) {
                                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
                            }
                        } label: {
                            ActionButton(icon: "square.and.arrow.up", count: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .task {
            localLikes = video.likes
            await checkIfLiked()
            await loadAvatarIfNeeded()
        }
        .sheet(item: $previewUser) { user in
            DiscoverUserPreviewSheet(user: user)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showComments) {
            VStack(spacing: 12) {
                Text("Comments")
                    .font(.headline)
                    .padding(.top)
                Text("Coming soon…")
                    .foregroundStyle(.secondary)
                Button("Close") { showComments = false }
                    .padding(.top, 12)
            }
            .padding()
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
    }
    
    private func toggleLike() async {
        guard let userId = authManager.currentUserId?.uuidString else { return }
        
        do {
            if isLiked {
                try await service.unlikeVideo(videoId: video.id, userId: userId)
                isLiked = false
            } else {
                try await service.likeVideo(videoId: video.id, userId: userId)
                isLiked = true
            }
        } catch {
            print("Error toggling like: \(error)")
        }
    }
    
    private func toggleLikeOptimistic() async {
        // Optimistically update UI
        if isLiked {
            isLiked = false
            localLikes = max(0, localLikes - 1)
            do { try await service.unlikeVideo(videoId: video.id, userId: authManager.currentUserId?.uuidString ?? "") } catch {
                // Revert on failure
                isLiked = true
                localLikes += 1
                print("Unlike failed: \(error)")
            }
        } else {
            isLiked = true
            localLikes += 1
            do { try await service.likeVideo(videoId: video.id, userId: authManager.currentUserId?.uuidString ?? "") } catch {
                // Revert on failure
                isLiked = false
                localLikes = max(0, localLikes - 1)
                print("Like failed: \(error)")
            }
        }
    }
    
    private func checkIfLiked() async {
        guard let userId = authManager.currentUserId?.uuidString else { return }
        
        do {
            isLiked = try await service.isVideoLiked(videoId: video.id, userId: userId)
        } catch {
            print("Error checking like status: \(error)")
        }
    }
    
    private func presentUserPreview(username: String) {
        // We only have username and not id/display/bio here; build a lightweight placeholder.
        let user = UserProfile(id: UUID(), username: username, display_name: nil, bio: nil)
        previewUser = user
    }
    
    private func incrementViewCount() async {
        do {
            try await service.incrementViews(videoId: video.id)
            NotificationCenter.default.post(name: .localViewCounted, object: nil, userInfo: ["videoId": video.id])
        } catch {
            // Non-fatal; ignore failures silently for now
            print("Failed to increment view: \(error)")
        }
    }
    
    private func loadAvatarIfNeeded() async {
        // Prefer typed properties on VideoPost when available. Avoid KVC to prevent runtime crashes.
        guard !isLoadingAvatar else { return }
        isLoadingAvatar = true
        defer { isLoadingAvatar = false }
        do {
            if let cached = AvatarURLCache.shared.url(for: video.username) {
                await MainActor.run { self.avatarURLString = cached }
                return
            }
            // Call a concrete method on SupabaseService if it exists; else, skip.
            if let url = try await fetchAvatarURL(service: service, username: video.username) {
                AvatarURLCache.shared.set(url: url, for: video.username)
                await MainActor.run { self.avatarURLString = url }
            }
        } catch {
            // Soft-fail: keep fallback avatar
            print("[Avatar] Failed to load avatar for @\(video.username): \(error)")
        }
    }
}

fileprivate func fetchAvatarURL(service: SupabaseService, username: String) async throws -> String? {
    // Prefer a strongly-typed API if available. If your SupabaseService doesn't implement this yet,
    // return nil to avoid compile errors.
    // Implementers can extend SupabaseService to add this method.
    if let svc = service as AnyObject as? (any AvatarURLProviding) {
        return try await svc.fetchUserAvatarURL(username: username)
    }
    return nil
}

// Protocol shim to avoid dynamic member lookup errors if the method exists in your codebase.
fileprivate protocol AvatarURLProviding {
    func fetchUserAvatarURL(username: String) async throws -> String?
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let count: Int?
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            if let count = count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}

// UploadHub moved to its own file `UploadHub.swift` to ensure global scope

// - [x] Hook up searchUsers() to a real backend API (SupabaseService.searchUsers(query:limit:)).
// - [x] Optionally filter userResults to only users that appear in discoverVideos (by username/user id).
// - [x] Add analytics for error states and retry taps in Discover.
// - [x] Use reusable GlassErrorCard to standardize error UI.
struct DiscoverView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var discoverVideos: [VideoPost] = []
    @State private var isLoading = false
    @State private var selectedVideo: VideoPost? = nil
    
    @State private var query: String = ""
    @State private var userResults: [UserProfile] = []
    @State private var selectedUser: UserProfile? = nil
    @State private var errorMessage: String? = nil
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryNeon)
                                .frame(width: 56, height: 56)
                                .neonGlow(intensity: 1.0, spread: 1.1)
                                .pulsingBloom(scale: 1.04, glowRadius: 28)

                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Discover")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                                .neonGlow(intensity: 0.9, spread: 1.0)

                            Text("Explore trending vibes and creators")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.leading, 4)

                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Search users
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.7))
                        TextField("Search users", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .onSubmit { Task { await searchUsers() } }
                        if !query.isEmpty {
                            Button {
                                query = ""
                                userResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    if !userResults.isEmpty && !discoverVideos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Users")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal)

                            ForEach(userResults) { user in
                                Button {
                                    // Navigate: for now, present a lightweight profile preview
                                    selectedUser = user
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundStyle(.white.opacity(0.9))
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.username)
                                                .foregroundStyle(.white)
                                            if let display = user.display_name, !display.isEmpty {
                                                Text(display)
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let errorMessage = errorMessage {
                        GlassErrorCard(
                            title: "We couldn’t load Discover right now.",
                            message: errorMessage,
                            retryAction: { Task { await loadDiscoverVideos() } }
                        )
                        .onAppear { print("[Analytics] Discover error_shown: \(errorMessage)") }
                        .padding(.vertical, 40)
                    } else if discoverVideos.isEmpty {
                        GlassEffectContainer(spacing: 20) {
                            VStack(spacing: 18) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                        .frame(width: 110, height: 110)
                                        .glassEffect(.regular, in: .circle)

                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.white.opacity(0.85))
                                }

                                Text("No videos to discover yet")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))

                                Button {
                                    Task { await loadDiscoverVideos() }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Refresh")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .padding(.horizontal, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 18)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.vbGlow.opacity(0.14), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(discoverVideos) { video in
                                Button {
                                    selectedVideo = video
                                } label: {
                                    ZStack {
                                        // Thumbnail if available, else gradient fallback
                                        Group {
                                            if let thumb = video.thumbnailURL, let url = URL(string: thumb) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        LinearGradient(
                                                            colors: [Color.vbPurple.opacity(0.55), Color.vbBlue.opacity(0.55)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                    case .failure:
                                                        LinearGradient(
                                                            colors: [Color.vbPurple.opacity(0.55), Color.vbBlue.opacity(0.55)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    @unknown default:
                                                        LinearGradient(
                                                            colors: [Color.vbPurple.opacity(0.55), Color.vbBlue.opacity(0.55)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    }
                                                }
                                            } else {
                                                LinearGradient(
                                                    colors: [Color.vbPurple.opacity(0.55), Color.vbBlue.opacity(0.55)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(9/16, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                        .contentShape(RoundedRectangle(cornerRadius: 8))
                                        .pulsingBloom(scale: 1.02, glowRadius: 26)

                                        VStack {
                                            Image(systemName: "play.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .padding(8)
                                                .background(Color.black.opacity(0.12))
                                                .clipShape(Circle())
                                                .neonGlow()

                                            Spacer()

                                            HStack {
                                                Image(systemName: "eye.fill")
                                                    .font(.caption2)
                                                Text("\(formatCount(video.views))")
                                                    .font(.caption2)

                                                Spacer()

                                                Image(systemName: "heart.fill")
                                                    .font(.caption2)
                                                Text("\(formatCount(video.likes))")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.10))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .padding(8)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.top)
            }
            .refreshable {
                await loadDiscoverVideos()
            }
        }
        .task {
            await loadDiscoverVideos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("VideoChanged"))) { _ in
            Task { await loadDiscoverVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("LikeChanged"))) { _ in
            Task { await loadDiscoverVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("CommentChanged"))) { _ in
            Task { await loadDiscoverVideos() }
        }
        .sheet(item: $selectedVideo) { video in
            DiscoverPreviewSheet(video: video)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedUser) { user in
            DiscoverUserPreviewSheet(user: user)
                .preferredColorScheme(.dark)
        }
    }
    
    private func loadDiscoverVideos() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let vids = try await service.fetchDiscoverVideos(limit: 30)
            discoverVideos = vids
            print("[Analytics] Discover load_success: count=\(vids.count)")
            errorMessage = nil
        } catch {
            errorMessage = "Something went wrong while loading Discover. Please check your connection and try again.\n\nDetails: \(error.localizedDescription)"
            print("Error loading discover videos: \(error)")
            print("[Analytics] Discover load_failed: \(error.localizedDescription)")
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    private func searchUsers() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Analytics] Discover search_start: query=\(trimmed)")
        guard !trimmed.isEmpty else {
            userResults = []
            return
        }
        do {
            // Call the service-backed searchUsers. We filter to users that appear in discoverVideos
            // when discover has items so the Users section remains relevant.
            let results = try await service.searchUsers(query: trimmed, limit: 10)

            if !discoverVideos.isEmpty {
                // If discover has videos, prefer users that appear in those results
                let usernames = Set(discoverVideos.map { $0.username })
                self.userResults = results.filter { usernames.contains($0.username) }
                if self.userResults.isEmpty {
                    // if none match, fall back to full results
                    self.userResults = results
                }
            } else {
                self.userResults = results
            }
            print("[Analytics] Discover search_success: results=\(self.userResults.count)")
        } catch {
            print("Error searching users: \(error)")
            print("[Analytics] Discover search_failed: \(error.localizedDescription)")
        }
    }

}

// Reusable error card used by DiscoverView (moved to top-level)
struct GlassErrorCard: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if let retry = retryAction {
                Button {
                    retry()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct DiscoverPreviewSheet: View {
    let video: VideoPost

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.vbPurple.opacity(0.55), Color.vbBlue.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 320)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.15))
                            .clipShape(Circle())
                    )
                    .pulsingBloom(scale: 1.02, glowRadius: 26)

            }

            VStack(alignment: .leading, spacing: 8) {
                Text(video.username)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(video.caption ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)

                HStack(spacing: 12) {
                    Label("\(formatCount(video.views))", systemImage: "eye.fill")
                    Label("\(formatCount(video.likes))", systemImage: "heart.fill")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding()
        .background(Color.vbBackground.ignoresSafeArea())
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

struct DiscoverUserPreviewSheet: View {
    let user: UserProfile

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let display = user.display_name, !display.isEmpty {
                        Text(display)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("No bio yet.")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            Button {
                let base = "https://vibex-dlam8go0k-prnhubstudio.vercel.app"
                if let url = URL(string: base + "/u/\(user.username)") {
                    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Profile")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .background(Color.vbBackground.ignoresSafeArea())
    }
}

// MARK: - Profile View V4

@MainActor
struct ProfileView: View {
    
    @EnvironmentObject var service: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedAvatarItem: PhotosPickerItem? = nil
    @State private var isUploadingAvatar: Bool = false
    @State private var showAvatarUploadError: Bool = false
    @State private var avatarUploadErrorMessage: String? = nil
    @State private var userVideos: [VideoPost] = []
    @State private var likedVideos: [VideoPost] = []
    @State private var savedVideos: [VideoPost] = []
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showNotifications = false
    @State private var selectedContentTab: ContentTab = .videos

    @State private var showSettings: Bool = false
    @State private var showShareSheet: Bool = false
    
    @State private var showAvatarSuccessToast: Bool = false
    @State private var showCopiedLinkToast: Bool = false
    @State private var lastAvatarPickAt: Date = .distantPast
    private let avatarPickDebounce: TimeInterval = 1.2
    
    // Access the tab selection from the environment
    @Environment(\.tabSelection) private var tabSelection
    
    enum ContentTab: String, CaseIterable {
        case videos = "Videos"
        case likes = "Likes"
        case saved = "Saved"
        
        var icon: String {
            switch self {
            case .videos: return "play.rectangle.fill"
            case .likes: return "heart.fill"
            case .saved: return "bookmark.fill"
            }
        }
    }
    
    private func profileShareURL(for username: String) -> URL? {
        let base = "https://vibex-dlam8go0k-prnhubstudio.vercel.app"
        // Compose a canonical path like /u/{username}
        var comps = URLComponents(string: base)
        comps?.path = "/u/\(username)"
        return comps?.url
    }
    
    private func copyProfileLink(_ username: String) {
        guard let url = profileShareURL(for: username) else { return }
        UIPasteboard.general.string = url.absoluteString
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.25)) { showCopiedLinkToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.25)) { showCopiedLinkToast = false }
        }
    }

    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    profileHeader
                    // Stats row (lightweight placeholders; wire real values if available)
                    HStack(spacing: 12) {
                        StatsItemV4(title: "Posts", value: "\(userVideos.count)")
                        StatsItemV4(title: "Likes", value: formatCount(totalLikes))
                        StatsItemV4(title: "Saved", value: "\(savedVideos.count)")
                    }
                    .padding(.horizontal)

                    // Segmented control for content tabs
                    Picker("Content", selection: $selectedContentTab) {
                        ForEach(ContentTab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Content grid switching by selected tab
                    Group {
                        switch selectedContentTab {
                        case .videos:
                            ContentGridV4(videos: userVideos, isLoading: isLoading, emptyMessage: "No videos yet.")
                        case .likes:
                            ContentGridV4(videos: likedVideos, isLoading: isLoading, emptyMessage: "No liked videos yet.")
                        case .saved:
                            ContentGridV4(videos: savedVideos, isLoading: isLoading, emptyMessage: "No saved videos yet.")
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 12)
                }
                .padding(.top, 12)
            }
            .refreshable { await refreshAll() }

            // Success toast for avatar
            if showAvatarSuccessToast {
                VStack {
                    Spacer()
                    Text("Avatar updated!")
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showCopiedLinkToast {
                VStack {
                    Spacer()
                    Text("Link copied!")
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await initialLoad() }
        .onReceive(NotificationCenter.default.publisher(for: .profileShouldRefresh)) { _ in
            Task { await refreshAll() }
        }
        .alert("Upload Failed", isPresented: $showAvatarUploadError) {
            Button("OK", role: .cancel) { avatarUploadErrorMessage = nil }
        } message: {
            Text(avatarUploadErrorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showShareSheet) {
            if let username = authManager.profile?.username {
                if let url = profileShareURL(for: username) {
                    ShareSheet(items: [url])
                } else {
                    ShareSheet(items: ["Check out my VibeX profile: https://vibex-dlam8go0k-prnhubstudio.vercel.app/u/\(username)"])
                }
            }
        }
    }
    
    private var totalLikes: Int {
        likedVideos.reduce(0) { $0 + $1.likes }
    }

    private func initialLoad() async {
        await refreshAll()
    }

    private func refreshAll() async {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadUserVideos() }
            group.addTask { await loadLikedVideos() }
            group.addTask { await loadSavedVideos() }
        }
    }

    private func loadUserVideos() async {
        do {
            if let userId = authManager.currentUserId?.uuidString {
                if let svc = service as AnyObject as? (any ProfileVideosProviding) {
                    let vids = try await svc.fetchUserVideos(userId: userId)
                    await MainActor.run { self.userVideos = vids }
                } else {
                    // Fallback: try a generic fetch if available
                    if let vids = try? await service.fetchUserVideos(userId: userId) {
                        await MainActor.run { self.userVideos = vids }
                    }
                }
            }
        } catch {
            print("[Profile] Failed to load user videos: \(error)")
        }
    }

    private func loadLikedVideos() async {
        do {
            if let userId = authManager.currentUserId?.uuidString {
                if let svc = service as AnyObject as? (any ProfileLikesProviding) {
                    let vids = try await svc.fetchLikedVideos(userId: userId)
                    await MainActor.run { self.likedVideos = vids }
                }
            }
        } catch {
            print("[Profile] Failed to load liked videos: \(error)")
        }
    }

    private func loadSavedVideos() async {
        do {
            if let userId = authManager.currentUserId?.uuidString {
                if let svc = service as AnyObject as? (any ProfileSavedProviding) {
                    let vids = try await svc.fetchSavedVideos(userId: userId)
                    await MainActor.run { self.savedVideos = vids }
                }
            }
        } catch {
            print("[Profile] Failed to load saved videos: \(error)")
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }

    // Break up large body for faster type checking
    private var profileHeader: some View {
        let username = authManager.profile?.username ?? "username"
        let displayName = authManager.profile?.display_name
        let avatarURLString = authManager.profile?.avatar_url

        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.vbPurple.opacity(0.35), Color.vbBlue.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.vbGlow.opacity(0.18), lineWidth: 1)
                )
                .glassySurface(cornerRadius: 24, opacity: 0.10)
                .neonGlow(intensity: theme.isNeon ? 1.0 : 0.4)

            HStack(alignment: .bottom, spacing: 16) {
                PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                    AvatarPickerContent(
                        avatarURLString: avatarURLString,
                        username: username,
                        isUploadingAvatar: isUploadingAvatar
                    )
                }
                .onChange(of: selectedAvatarItem) { _, newItem in
                    let now = Date()
                    if isUploadingAvatar || now.timeIntervalSince(lastAvatarPickAt) < avatarPickDebounce { return }
                    lastAvatarPickAt = now

                    Task {
                        guard let item = newItem else { return }
                        isUploadingAvatar = true
                        defer { isUploadingAvatar = false }
                        
                        do {
                            // Load the image data
                            guard let data = try await item.loadTransferable(type: Data.self) else {
                                avatarUploadErrorMessage = "Could not load image data"
                                showAvatarUploadError = true
                                return
                            }
                            
                            // Resize and compress
                            let maxDim: CGFloat = 1024
                            let quality: CGFloat = 0.80
                            let uploadData: Data
                            if let resized = resizeImageData(data, maxDimension: maxDim, compressionQuality: quality) {
                                uploadData = resized
                            } else {
                                uploadData = data
                            }

                            guard let userId = authManager.currentUserId else { 
                                avatarUploadErrorMessage = "No user ID available"
                                showAvatarUploadError = true
                                return
                            }
                            
                            // Upload to server
                            let url = try await service.uploadProfileImage(userId: userId, imageData: uploadData, contentType: "image/jpeg")
                            
                            // Success feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            await MainActor.run {
                                authManager.profile?.avatar_url = url.absoluteString
                                showAvatarSuccessToast = true
                            }
                            
                            NotificationCenter.default.post(name: .profileShouldRefresh, object: nil)
                            
                            // Hide toast after delay
                            try? await Task.sleep(nanoseconds: 1_600_000_000)
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.3)) { 
                                    showAvatarSuccessToast = false 
                                }
                            }
                            
                        } catch {
                            let msg = String(describing: error)
                            await MainActor.run {
                                if msg.contains("409") || msg.localizedCaseInsensitiveContains("conflict") || msg.localizedCaseInsensitiveContains("already exists") || msg.localizedCaseInsensitiveContains("Duplicate") {
                                    avatarUploadErrorMessage = "We couldn't replace your avatar due to a storage conflict. Please try again."
                                } else {
                                    avatarUploadErrorMessage = "Upload failed: \(error.localizedDescription)"
                                }
                                showAvatarUploadError = true
                            }
                            print("Failed to upload avatar: \(error)")
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("@\(username)")
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.9)
                        .layoutPriority(1)

                    if let displayName = displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.9)
                    }
                }
                .padding(.bottom, 16)

                Spacer()

                VStack(spacing: 10) {
                    Button { showNotifications = true } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button { theme.setNeon(!theme.isNeon) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: theme.isNeon ? "bolt.fill" : "sparkles")
                            Text(theme.isNeon ? "Neon" : "Luxury")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(minWidth: 0)
                    .buttonStyle(.plain)

                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    if let username = authManager.profile?.username, !username.isEmpty {
                        Button { copyProfileLink(username) } label: {
                            Image(systemName: "link")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal)
    }
    
    private func handleAvatarSelection(_ newItem: PhotosPickerItem?) {
        let now = Date()
        if isUploadingAvatar || now.timeIntervalSince(lastAvatarPickAt) < avatarPickDebounce { return }
        lastAvatarPickAt = now
        
        Task {
            guard let item = newItem else { return }
            isUploadingAvatar = true
            defer { isUploadingAvatar = false }
            
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        avatarUploadErrorMessage = "Could not load image data"
                        showAvatarUploadError = true
                    }
                    return
                }
                
                let maxDim: CGFloat = 1024
                let quality: CGFloat = 0.80
                let uploadData: Data
                if let resized = resizeImageData(data, maxDimension: maxDim, compressionQuality: quality) {
                    uploadData = resized
                } else {
                    uploadData = data
                }
                
                guard let userId = authManager.currentUserId else {
                    await MainActor.run {
                        avatarUploadErrorMessage = "No user ID available"
                        showAvatarUploadError = true
                    }
                    return
                }
                
                let url = try await service.uploadProfileImage(userId: userId, imageData: uploadData, contentType: "image/jpeg")
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                await MainActor.run {
                    authManager.profile?.avatar_url = url.absoluteString
                    showAvatarSuccessToast = true
                }
                
                NotificationCenter.default.post(name: .profileShouldRefresh, object: nil)
                
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAvatarSuccessToast = false
                    }
                }
            } catch {
                let msg = String(describing: error)
                await MainActor.run {
                    if msg.contains("409") || msg.localizedCaseInsensitiveContains("conflict") {
                        avatarUploadErrorMessage = "Storage conflict. Please try again."
                    } else {
                        avatarUploadErrorMessage = "Upload failed: \(error.localizedDescription)"
                    }
                    showAvatarUploadError = true
                }
            }
        }
    }
}

struct StatsItemV4: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContentGridV4: View {
    let videos: [VideoPost]
    let isLoading: Bool
    let emptyMessage: String
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if videos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(videos) { video in
                        VideoThumbnailV4(video: video)
                    }
                }
            }
        }
    }
}

struct VideoThumbnailV4: View {
    let video: VideoPost
    @State private var fallbackImage: UIImage? = nil

    // Compute expected grid column width (3 columns with small spacing)
    private var cellWidth: CGFloat {
        let totalSpacing: CGFloat = 4 // two gaps of 2pts between three columns
        let screenWidth = UIScreen.main.bounds.width
        return (screenWidth - totalSpacing) / 3.0
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumb = video.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url, scale: 1) { phase in
                        switch phase {
                        case .empty:
                            Color.white.opacity(0.06)
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            LinearGradient(
                                colors: [Color.vbPurple.opacity(0.45), Color.vbBlue.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        @unknown default:
                            LinearGradient(
                                colors: [Color.vbPurple.opacity(0.45), Color.vbBlue.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                } else {
                    if let img = fallbackImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 96, height: 96)
                            .glassEffect(.regular, in: .circle)
                            .neonGlow()

                        Text(String(video.username.prefix(1)).uppercased())
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: cellWidth, height: cellWidth * (16.0/9.0))
            .clipped()
            .onAppear {
                Task {
                    guard fallbackImage == nil else { return }
                    let cacheKey = video.id
                    if let cached = ThumbnailCache.shared.image(forKey: cacheKey) {
                        fallbackImage = cached
                        return
                    }
                    guard let url = URL(string: video.videoURL) else { return }
                    if let img = await generateFrameThumbnail(from: url) {
                        ThumbnailCache.shared.set(img, forKey: cacheKey)
                        fallbackImage = img
                    }
                }
            }
            
            // View count overlay
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                Text(formatCount(video.views))
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(6)
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Old Components (kept for compatibility)

struct StatView: View {
    let title: String
    let count: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct GlassStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

private func resizeImageData(_ data: Data, maxDimension: CGFloat, compressionQuality: CGFloat) -> Data? {
    guard let image = UIImage(data: data) else {
        print("[Resize] invalid input image data (undecodable)")
        return nil
    }
    let size = image.size
    guard size.width > 0, size.height > 0 else {
        print("[Resize] invalid image size: \(size)")
        return nil
    }
    let aspect = size.width / size.height
    var newSize: CGSize
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspect)
    } else {
        newSize = CGSize(width: maxDimension * aspect, height: maxDimension)
    }
    newSize.width = max(newSize.width, 1)
    newSize.height = max(newSize.height, 1)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1 // keep bytes/row sane and deterministic
    format.opaque = false
    if #available(iOS 15.0, *) {
        format.preferredRange = .standard // 8-bit sRGB
    }

    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let rendered = renderer.image { ctx in
        UIColor.clear.setFill()
        ctx.fill(CGRect(origin: .zero, size: newSize))
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }

    guard let output = rendered.jpegData(compressionQuality: compressionQuality) else {
        print("[Resize] failed to create JPEG data")
        return nil
    }
    print("[Resize] input bytes: \(data.count) -> output bytes: \(output.count), size: \(rendered.size)")
    return output
}

// MARK: - Avatar Picker Content View
private struct AvatarPickerContent: View {
    let avatarURLString: String?
    let username: String
    let isUploadingAvatar: Bool
    
    var body: some View {
        ZStack {
            // Avatar image or fallback initial
            Group {
                if let urlString = avatarURLString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle().fill(Color.white.opacity(0.10))
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Circle().fill(Color.white.opacity(0.10))
                        @unknown default:
                            Circle().fill(Color.white.opacity(0.10))
                        }
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .glassEffect(.regular, in: .circle)
            .neonGlow()
            
            // Uploading overlay
            if isUploadingAvatar {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
    }
}

// Lightweight in-memory cache for generated thumbnails to avoid re-generating on scroll.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 200 }

    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

final class AvatarURLCache {
    static let shared = AvatarURLCache()
    private var cache: [String: String] = [:] // username -> avatarURL
    private let lock = NSLock()
    func url(for username: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return cache[username]
    }
    func set(url: String, for username: String) {
        lock.lock(); defer { lock.unlock() }
        cache[username] = url
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Temporary Service Stubs (remove when real implementations exist)
// Removed as per instructions

fileprivate protocol ProfileVideosProviding {
    func fetchUserVideos(userId: String) async throws -> [VideoPost]
}

fileprivate protocol ProfileLikesProviding {
    func fetchLikedVideos(userId: String) async throws -> [VideoPost]
}

fileprivate protocol ProfileSavedProviding {
    func fetchSavedVideos(userId: String) async throws -> [VideoPost]
}

#Preview {
    RootView()
        .environmentObject(AuthManager.shared)
        .environmentObject(SupabaseService.shared)
}

