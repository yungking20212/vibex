import SwiftUI
import Combine
import AVKit
import PhotosUI

// MARK: - NextGen Profile UI (No backend placeholders)
// UI-only. No mock endpoints, no fake DB fields.
// Pass real data into the view-model later.

// MARK: - Theme (Match your VibeX / RayGlow vibe)
enum VibeXTheme: String, CaseIterable, Hashable {
    case rayGlowNeon = "RayGlow Neon"
    case stealth = "Stealth"
    case glass = "Glass"

    var accent: Color {
        switch self {
        case .rayGlowNeon: return .cyan
        case .stealth: return .purple
        case .glass: return .white
        }
    }

    var bg: LinearGradient {
        switch self {
        case .rayGlowNeon:
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color.cyan.opacity(0.18),
                    Color.black.opacity(0.92),
                    Color.blue.opacity(0.10),
                    Color.black.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .stealth:
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.96),
                    Color.purple.opacity(0.18),
                    Color.black.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .glass:
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    Color.white.opacity(0.06),
                    Color.black.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var glassStroke: Color { Color.white.opacity(0.10) }
    var glassFill: Color { Color.white.opacity(0.06) }

    func tileGradient(strength: Double = 0.22) -> LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(strength),
                Color.white.opacity(0.05),
                Color.blue.opacity(0.10),
                Color.black.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Models (UI-safe)
struct ProfileStats: Hashable {
    var followers: Int
    var following: Int
    var likes: Int
    var views: Int
    var earnings: Double = 0
}

enum ProfileTab: String, CaseIterable, Hashable {
    case videos = "Videos"
    case media = "Media"
    case aiStudio = "AI Studio"
    case social = "Social"
    case about = "About"

    var icon: String {
        switch self {
        case .videos: return "play.rectangle.fill"
        case .media: return "photo.on.rectangle"
        case .aiStudio: return "sparkles.rectangle.stack.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .about: return "info.circle.fill"
        }
    }
}

enum AIStudioTool: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case caption = "AI Captions"
    case hashtags = "Hashtags"
    case story = "AI Story"
    case clone = "AI Clone"
    case funny = "AI Funny"
    case musicVideo = "AI Music Video"
    case boost = "Boost Post"

    var icon: String {
        switch self {
        case .caption: return "captions.bubble.fill"
        case .hashtags: return "number"
        case .story: return "book.fill"
        case .clone: return "person.crop.square.filled.and.at.rectangle"
        case .funny: return "face.smiling.fill"
        case .musicVideo: return "music.note.tv.fill"
        case .boost: return "bolt.fill"
        }
    }

    var isLive: Bool {
        switch self {
        case .caption, .hashtags: return true
        default: return false
        }
    }

    var tagline: String {
        switch self {
        case .caption: return "One-tap captions in your brand style."
        case .hashtags: return "Smart tags that match the vibe."
        case .story: return "Turn clips into story posts."
        case .clone: return "Real-time clone (style + motion)."
        case .funny: return "Auto skits + meme edits."
        case .musicVideo: return "Sync visuals to your track."
        case .boost: return "AI growth coach + boost."
        }
    }
}

// MARK: - ViewModel (UI-only; bind real data later)
@MainActor
final class NextGenProfileVM: ObservableObject {
    // Backend hook to perform follow/unfollow on server
    struct Backend {
        var follow: (_ username: String) async throws -> Void
        var unfollow: (_ username: String) async throws -> Void
    }

    // Inject real backend from the app. Defaults to no-op.
    var backend: Backend = .init(
        follow: { _ in },
        unfollow: { _ in }
    )

    // Error callback for follow/unfollow failures
    var onFollowError: ((Error) -> Void)?

    private let profileImageFileName = "profile_image.jpg"

    @Published var theme: VibeXTheme = .rayGlowNeon
    @Published var selectedTab: ProfileTab = .videos
    @Published var headerExpanded: Bool = false

    @Published var username: String = "vibex"
    @Published var displayName: String = "VibeX"
    @Published var bio: String = "Next-gen creator. AI tools. Viral edits. 🚀"
    @Published var isVerified: Bool = true
    @Published var stats: ProfileStats = .init(followers: 128_400, following: 120, likes: 2_840_000, views: 48_900_000)

    @Published var videoItems: [String] = []
    @Published var mediaItems: [String] = []
    @Published var socialItems: [String] = []

    // Indicates if this profile is the signed-in user's own profile
    @Published var isCurrentUser: Bool = true

    @Published var isFollowing: Bool = false

    // Callbacks for stat taps
    var onTapFollowers: (() -> Void)?
    var onTapFollowing: (() -> Void)?
    var onTapLikes: (() -> Void)?
    var onTapViews: (() -> Void)?

    // Follow toggle callback (passes new state)
    var onToggleFollow: ((Bool) -> Void)?

    func toggleFollow() {
        // Optimistic update
        let wasFollowing = isFollowing
        let previousFollowers = stats.followers

        isFollowing.toggle()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if !wasFollowing && isFollowing {
                stats.followers = max(0, stats.followers + 1)
            } else if wasFollowing && !isFollowing {
                stats.followers = max(0, stats.followers - 1)
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onToggleFollow?(isFollowing)

        Task { [username] in
            do {
                if isFollowing {
                    try await backend.follow(username)
                } else {
                    try await backend.unfollow(username)
                }
            } catch {
                // Roll back on failure
                await MainActor.run {
                    isFollowing = wasFollowing
                    stats.followers = previousFollowers
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    onFollowError?(error)
                }
            }
        }
    }

    init() {
        self.profileImage = loadProfileImageFromDisk()
    }

    // Profile image (UI-only; store/restore elsewhere later)
    @Published var profileImage: UIImage? = nil

    private func documentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func profileImageURL() -> URL? {
        documentsURL()?.appendingPathComponent(profileImageFileName)
    }

    private func saveProfileImageToDisk(_ image: UIImage?) {
        guard let url = profileImageURL() else { return }
        if let image, let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadProfileImageFromDisk() -> UIImage? {
        guard let url = profileImageURL(), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func setProfileImage(_ image: UIImage?) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.profileImage = image
        }
        saveProfileImageToDisk(image)
    }

    var onTapVideo: ((Int) -> Void)? = nil
    var onTapTool: ((AIStudioTool) -> Void)? = nil
    var onEditProfile: (() -> Void)? = nil

    func select(_ tab: ProfileTab) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedTab = tab
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func toggleHeader() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            headerExpanded.toggle()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Main View
struct NextGenProfileView: View {
    @StateObject var vm: NextGenProfileVM

    init(vm: NextGenProfileVM) {
        _vm = StateObject(wrappedValue: vm)
    }

    init() {
        _vm = StateObject(wrappedValue: NextGenProfileVM())
    }

    @Namespace private var tabNS

    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var showEditProfile = false
    @State private var showCamera = false
    @State private var showShareSheet = false
    @State private var showSettings = false
    @State private var settingsPreselect: SettingsView.SettingsSection? = nil
    @State private var settingsViewAsUserIdOverride: UUID? = nil
    private let shareURL = URL(string: "https://prnhub-e3r9385md-prnhubstudio.vercel.app")!

    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showErrorToast = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            vm.theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header

                    if !vm.isCurrentUser {
                        QuickActionButton(title: vm.isFollowing ? "Following" : "Follow",
                                          icon: vm.isFollowing ? "checkmark" : "person.badge.plus",
                                          theme: vm.theme) {
                            vm.toggleFollow()
                        }
                        .padding(.horizontal, 16)
                    }

                    statRow

                    tabBar
                        .padding(.horizontal, 12)

                    tabBody
                        .padding(.horizontal, 12)
                        .padding(.bottom, 24)
                }
                .padding(.top, 12)
            }
            .refreshable {
                try? await Task.sleep(nanoseconds: 600_000_000)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            if showErrorToast {
                VStack {
                    Spacer()
                    ErrorToast(message: errorMessage, theme: vm.theme)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Theme", selection: $vm.theme) {
                        ForEach(VibeXTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette.fill")
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileFlow(vm: vm)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                vm.setProfileImage(image)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [shareURL])
        }
        .sheet(isPresented: $showFollowers) {
            PlaceholderListView(title: "Followers", count: vm.stats.followers, theme: vm.theme)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFollowing) {
            PlaceholderListView(title: "Following", count: vm.stats.following, theme: vm.theme)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(preselectedSection: settingsPreselect, viewAsUserIdOverride: settingsViewAsUserIdOverride)
                .environmentObject(AuthManager.shared)
                .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            BannerCard(theme: vm.theme)
                .frame(height: vm.headerExpanded ? 220 : 170)
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 14) {

                        AvatarRing(theme: vm.theme, image: vm.profileImage)
                            .frame(width: vm.headerExpanded ? 92 : 78, height: vm.headerExpanded ? 92 : 78)
                            .onTapGesture {
                                showPhotoPicker = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("@\(vm.username)")
                                    .font(.system(size: vm.headerExpanded ? 18 : 16, weight: .semibold))
                                if vm.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(vm.theme.accent.opacity(0.9))
                                }
                            }

                            Text(vm.displayName)
                                .font(.system(size: vm.headerExpanded ? 22 : 19, weight: .bold))

                            if vm.headerExpanded {
                                Text(vm.bio)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.80))
                                    .lineLimit(3)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Spacer()

                        Menu {
                            Button("Change Photo", systemImage: "photo.on.rectangle") {
                                showPhotoPicker = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            Button("Take Photo", systemImage: "camera") {
                                showCamera = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            if vm.profileImage != nil {
                                Button("Remove Photo", systemImage: "trash") {
                                    vm.setProfileImage(nil)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                            Button("Edit Profile", systemImage: "pencil") {
                                showEditProfile = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            Button("Share", systemImage: "square.and.arrow.up") {
                                showShareSheet = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            Button("Settings", systemImage: "gearshape") {
                                // Open settings normally
                                settingsPreselect = nil
                                settingsViewAsUserIdOverride = nil
                                showSettings = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            Button("Admin Tools", systemImage: "lock.shield") {
                                // Open Settings pre-selected to Admin Tools and view-as the admin UUID
                                settingsPreselect = SettingsView.SettingsSection.admin
                                settingsViewAsUserIdOverride = UUID(uuidString: "64c13e5b-04fe-493a-b030-a7d332bd3600")
                                showSettings = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            Section("Theme") {
                                Picker("Theme", selection: $vm.theme) {
                                    ForEach(VibeXTheme.allCases, id: \.self) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                            }
                        } label: {
                            CircleAction(icon: "ellipsis", theme: vm.theme) {}
                        }
                    }
                    .padding(14)
                }
                .onTapGesture { vm.toggleHeader() }
                .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
                .onChange(of: pickedItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            vm.setProfileImage(uiImage)
                        }
                    }
                }
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            StatPill(title: "Followers", value: vm.stats.followers, theme: vm.theme) {
                if let action = vm.onTapFollowers { action() } else { showFollowers = true }
            }
            StatPill(title: "Following", value: vm.stats.following, theme: vm.theme) {
                if let action = vm.onTapFollowing { action() } else { showFollowing = true }
            }
            StatPill(title: "Likes", value: vm.stats.likes, theme: vm.theme) {
                vm.onTapLikes?()
            }
            StatPill(title: "Views", value: vm.stats.views, theme: vm.theme) {
                vm.onTapViews?()
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    TabPill(tab: tab, selected: vm.selectedTab == tab, theme: vm.theme, namespace: tabNS)
                        .onTapGesture { vm.select(tab) }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(vm.theme.glassStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tabBody: some View {
        switch vm.selectedTab {
        case .videos:
            VideosTab(theme: vm.theme, items: vm.videoItems) { idx in
                vm.onTapVideo?(idx)
            }
        case .media:
            MediaTab(theme: vm.theme, items: vm.mediaItems)
        case .aiStudio:
            AIStudioTab(theme: vm.theme) { tool in
                vm.onTapTool?(tool)
            }
        case .social:
            SocialTab(theme: vm.theme, items: vm.socialItems)
        case .about:
            AboutTab(theme: vm.theme, bio: vm.bio)
        }
    }
}

extension NextGenProfileView {
    func onProfileActions(
        followers: (() -> Void)? = nil,
        following: (() -> Void)? = nil,
        likes: (() -> Void)? = nil,
        views: (() -> Void)? = nil,
        toggleFollow: ((Bool) -> Void)? = nil,
        followError: ((Error) -> Void)? = nil
    ) -> Self {
        vm.onTapFollowers = followers
        vm.onTapFollowing = following
        vm.onTapLikes = likes
        vm.onTapViews = views
        vm.onToggleFollow = toggleFollow
        if let followError {
            vm.onFollowError = followError
        } else {
            vm.onFollowError = { error in
                errorMessage = (error as NSError).localizedDescription
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showErrorToast = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showErrorToast = false
                        }
                    }
                }
            }
        }
        return self
    }

    func withFollowBackend(follow: @escaping (_ username: String) async throws -> Void,
                           unfollow: @escaping (_ username: String) async throws -> Void) -> Self {
        vm.backend = .init(follow: follow, unfollow: unfollow)
        return self
    }
}

// MARK: - Components (All themed; no gray)

private struct BannerCard: View {
    let theme: VibeXTheme
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                ZStack {
                    theme.tileGradient(strength: 0.28)
                        .blendMode(.plusLighter)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(shimmer ? 0.08 : 0.02),
                                    theme.accent.opacity(shimmer ? 0.16 : 0.06),
                                    Color.white.opacity(shimmer ? 0.06 : 0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.9)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: shimmer)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(theme.glassStroke, lineWidth: 1)
            )
            .shadow(radius: 18, y: 10)
            .padding(.horizontal, 12)
            .onAppear { shimmer = true }
    }
}

private struct AvatarRing: View {
    let theme: VibeXTheme
    var image: UIImage? = nil
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(theme.accent.opacity(0.55), lineWidth: 2))
                .shadow(radius: 10, y: 6)

            Circle()
                .stroke(theme.accent.opacity(pulse ? 0.70 : 0.25), lineWidth: pulse ? 6 : 2)
                .scaleEffect(pulse ? 1.08 : 0.98)
                .blur(radius: 0.6)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white.opacity(0.90))
            }
        }
        .onAppear { pulse = true }
    }
}

private struct CircleAction: View {
    let icon: String
    let theme: VibeXTheme
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: icon).font(.system(size: 14, weight: .bold)))
                .overlay(Circle().strokeBorder(theme.accent.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct StatPill: View {
    let title: String
    let value: Int
    let theme: VibeXTheme
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 3) {
            Text(shortNumber(value))
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap?()
        }
        .onLongPressGesture {
            UIPasteboard.general.string = String(value)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .accessibilityLabel("\(title) \(value)")
    }
}

private struct TabPill: View {
    let tab: ProfileTab
    let selected: Bool
    let theme: VibeXTheme
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.icon).font(.system(size: 13, weight: .bold))
            Text(tab.rawValue).font(.system(size: 13, weight: .semibold))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .foregroundStyle(.white.opacity(selected ? 0.95 : 0.70))
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.accent.opacity(0.16))
                    .matchedGeometryEffect(id: "tabHighlight", in: namespace)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.accent.opacity(selected ? 0.28 : 0.10), lineWidth: 1)
        )
        .scaleEffect(selected ? 1.02 : 0.98)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
    }
}

// MARK: - Tabs

private struct VideosTab: View {
    let theme: VibeXTheme
    let items: [String]
    var onTap: (Int) -> Void

    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Videos", subtitle: "Tap to open", icon: "play.fill", theme: theme)

            if !items.isEmpty {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(items.indices, id: \.self) { idx in
                        NeonTile(theme: theme)
                            .frame(height: 150)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onTap(idx)
                            }
                    }
                }
            } else {
                Text("No videos yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(.top, 8)
    }
}

private struct MediaTab: View {
    let theme: VibeXTheme
    let items: [String]
    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Media", subtitle: "Photos + thumbnails", icon: "photo.fill", theme: theme)

            if !items.isEmpty {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(items.indices, id: \.self) { _ in
                        NeonTile(theme: theme)
                            .frame(height: 170)
                    }
                }
            } else {
                Text("No media yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(.top, 8)
    }
}

private struct AIStudioTab: View {
    let theme: VibeXTheme
    var onTap: (AIStudioTool) -> Void

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "AI Studio", subtitle: "Your creator tools", icon: "sparkles", theme: theme)

            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(AIStudioTool.allCases) { tool in
                    AIStudioToolCard(theme: theme, tool: tool) { onTap(tool) }
                }
            }
        }
        .padding(.top, 8)
    }
}

private struct SocialTab: View {
    let theme: VibeXTheme
    let items: [String]

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Social", subtitle: "Mentions + replies", icon: "bubble.left.fill", theme: theme)

            if !items.isEmpty {
                ForEach(items.indices, id: \.self) { _ in
                    GlassCard(theme: theme) {
                        HStack(spacing: 12) {
                            Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Activity").font(.system(size: 14, weight: .bold))
                                Text("New interaction").font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            Spacer()
                        }
                        .padding(14)
                    }
                }
            } else {
                Text("No activity yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(.top, 8)
    }
}

private struct AboutTab: View {
    let theme: VibeXTheme
    let bio: String

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "About", subtitle: "Bio + info", icon: "info.circle.fill", theme: theme)
            GlassCard(theme: theme) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bio").font(.system(size: 15, weight: .bold))
                    Text(bio)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(14)
            }
        }
        .padding(.top, 8)
    }
}

private struct AIStudioToolCard: View {
    let theme: VibeXTheme
    let tool: AIStudioTool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.accent.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(theme.accent.opacity(0.22), lineWidth: 1)
                            )
                        Image(systemName: tool.icon)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(width: 44, height: 44)

                    Spacer()

                    Text(tool.isLive ? "LIVE" : "COMING SOON")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(tool.isLive ? theme.accent.opacity(0.18) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 999))
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .strokeBorder(theme.accent.opacity(tool.isLive ? 0.35 : 0.12), lineWidth: 1)
                        )
                }

                Text(tool.rawValue)
                    .font(.system(size: 15, weight: .bold))

                Text(tool.tagline)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)

                Spacer()

                HStack {
                    Text(tool.isLive ? "Open" : "Preview")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(theme.accent.opacity(tool.isLive ? 0.16 : 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(14)
            .frame(height: 170)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(theme.glassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct NeonTile: View {
    let theme: VibeXTheme
    @State private var glow = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(theme.tileGradient(strength: 0.26).blendMode(.plusLighter))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.accent.opacity(glow ? 0.30 : 0.16), lineWidth: 1)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)
            )
            .shadow(radius: 14, y: 8)
            .onAppear { glow = true }
    }
}

private struct GlassCard<Content: View>: View {
    let theme: VibeXTheme
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(content.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(theme.glassStroke, lineWidth: 1)
            )
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let theme: VibeXTheme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.accent.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
            }

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

private func shortNumber(_ n: Int) -> String {
    let num = Double(n)
    if num >= 1_000_000_000 { return String(format: "%.1fB", num / 1_000_000_000) }
    if num >= 1_000_000 { return String(format: "%.1fM", num / 1_000_000) }
    if num >= 1_000 { return String(format: "%.1fK", num / 1_000) }
    return "\(n)"
}

#Preview {
    NavigationStack {
        NextGenProfileView()
    }
}

// MARK: - Extended Components

private enum Badge: String, CaseIterable, Hashable {
    case pro = "Pro"
    case verified = "Verified"
    case pioneer = "Pioneer"

    var icon: String {
        switch self {
        case .pro: return "star.fill"
        case .verified: return "checkmark.seal.fill"
        case .pioneer: return "flame.fill"
        }
    }
}

private struct BadgePill: View {
    let badge: Badge
    let theme: VibeXTheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: badge.icon).font(.system(size: 12, weight: .bold))
            Text(badge.rawValue).font(.system(size: 12, weight: .semibold))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .strokeBorder(theme.accent.opacity(0.20), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 999))
    }
}

private struct StatRow: View {
    @ObservedObject var vm: NextGenProfileVM

    var body: some View {
        HStack(spacing: 10) {
            StatPill(title: "Followers", value: vm.stats.followers, theme: vm.theme)
            StatPill(title: "Likes", value: vm.stats.likes, theme: vm.theme)
            StatPill(title: "Views", value: vm.stats.views, theme: vm.theme)
            if vm.headerExpanded {
                Text("Expanded")
            }
        }
    }
}

private struct NextGenTabBar: View {
    let selected: ProfileTab
    let tabs: [ProfileTab]
    let namespace: Namespace.ID
    let onSelect: (ProfileTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        onSelect(tab)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            ZStack {
                                if tab == selected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .matchedGeometryEffect(id: "tabHighlight", in: namespace)
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial.opacity(0.6))
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .foregroundStyle(tab == selected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
    }
}

private struct ProfileQuickActions: View {
    @ObservedObject var vm: NextGenProfileVM

    var body: some View {
        HStack(spacing: 12) {
            if vm.isCurrentUser {
                // No quick actions for own profile; actions live in 3-dot menu
            } else {
                QuickActionButton(title: "Follow", icon: "person.badge.plus", theme: vm.theme) {
                    // follow
                }

                QuickActionButton(title: "Message", icon: "paperplane.fill", theme: vm.theme) {
                    // message
                }

                QuickActionButton(title: "Share", icon: "square.and.arrow.up", theme: vm.theme) {
                    // share
                }
            }
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let theme: VibeXTheme
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.20), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct EditProfileFlow: View {
    @ObservedObject var vm: NextGenProfileVM

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display name", text: Binding(
                        get: { vm.displayName },
                        set: { vm.displayName = $0 }
                    ))
                    TextField("Username", text: Binding(
                        get: { vm.username },
                        set: { vm.username = $0 }
                    ))
                    TextField("Bio", text: Binding(
                        get: { vm.bio },
                        set: { vm.bio = $0 }
                    ), axis: .vertical)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { }
                }
            }
        }
    }
}

// MARK: - ImagePicker for Camera Capture
private struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType { case camera, photoLibrary }
    var sourceType: SourceType = .photoLibrary
    var onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = (sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera)) ? .camera : .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        init(onImagePicked: @escaping (UIImage?) -> Void) { self.onImagePicked = onImagePicked }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - ActivityView for Share Sheet

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Placeholder Lists for Followers/Following

private struct PlaceholderListView: View {
    let title: String
    let count: Int
    let theme: VibeXTheme

    var body: some View {
        NavigationStack {
            List(0..<max(count, 10), id: \.self) { idx in
                HStack(spacing: 12) {
                    Circle().fill(.ultraThinMaterial).frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User \(idx + 1)").font(.system(size: 14, weight: .bold))
                        Text("@handle\(idx + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(title)
        }
    }
}

private struct ErrorToast: View {
    let message: String
    let theme: VibeXTheme
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(theme.accent.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(message.isEmpty ? "Something went wrong. Please try again." : message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 12, y: 8)
        .accessibilityLabel("Error: \(message)")
    }
}

enum SupabaseFollowsAPI {
    // Set these from your app bootstrap
    static var projectRef: String = "<your-project-ref>" // e.g. jnkzbfqrwkgfiyxvwrug
    static var apiKey: String = "<your-anon-or-service-key>"
    static var jwtProvider: () -> String? = { nil } // return the user's JWT
    private static var baseURL: URL { URL(string: "https://\(projectRef).supabase.co/rest/v1")! }

    struct FollowRow: Encodable { let follower_id: UUID; let following_id: UUID }

    // POST /rest/v1/follows { follower_id, following_id }
    static func follow(followerID: UUID, followingID: UUID) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("follows"))
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let jwt = jwtProvider() { req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(FollowRow(follower_id: followerID, following_id: followingID))

        let (_, resp) = try await URLSession.shared.data(for: req)
        try validate(resp)
    }

    // DELETE /rest/v1/follows?follower_id=eq.<id>&following_id=eq.<id>
    static func unfollow(followerID: UUID, followingID: UUID) async throws {
        var comps = URLComponents(url: baseURL.appendingPathComponent("follows"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "follower_id", value: "eq.\(followerID.uuidString)"),
            .init(name: "following_id", value: "eq.\(followingID.uuidString)")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let jwt = jwtProvider() { req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, resp) = try await URLSession.shared.data(for: req)
        try validate(resp)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200..<300: return
        case 409: return // unique violation: already followed -> treat as success
        default:
            throw NSError(domain: "SupabaseFollowsAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error \(http.statusCode)"])
        }
    }
}

// Usage example to inject into the view (replace IDs and providers in your app bootstrap):
// let followerID = UUID(uuidString: "<current-user-uuid>")!
// let followingID = UUID(uuidString: "<profile-owner-uuid>")!
// SupabaseFollowsAPI.projectRef = "<your-project-ref>"
// SupabaseFollowsAPI.apiKey = "<your-anon-or-service-key>"
// SupabaseFollowsAPI.jwtProvider = { CurrentAuth.jwt }
// NextGenProfileView()
//   .withFollowBackend(
//       follow: { _ in try await SupabaseFollowsAPI.follow(followerID: followerID, followingID: followingID) },
//       unfollow: { _ in try await SupabaseFollowsAPI.unfollow(followerID: followerID, followingID: followingID) }
//   )


