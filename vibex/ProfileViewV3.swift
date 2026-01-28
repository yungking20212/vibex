import SwiftUI
import PhotosUI
import Auth
import UIKit

@MainActor
struct ProfileViewV3: View {
    @EnvironmentObject var service: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.tabSelection) private var tabSelection

    @State private var selectedAvatarItem: PhotosPickerItem? = nil
    @State private var isUploadingAvatar: Bool = false
    @State private var showAvatarUploadError: Bool = false
    @State private var avatarUploadErrorMessage: String? = nil

    @State private var userVideos: [VideoPost] = []
    @State private var isLoading = false

    @State private var showNotifications = false
    @State private var showEditProfile = false
    @State private var appearanceSelection: String = "Classic"
    @State private var glowIntensity: Double = 1.0

    var body: some View {
        let username = authManager.profile?.username ?? "username"
        let displayName = authManager.profile?.display_name
        let avatarURLString = authManager.profile?.avatar_url

        ZStack {
            Color.vbBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // MARK: - Header v3
                    profileHeader(
                        username: username,
                        displayName: displayName,
                        avatarURLString: avatarURLString
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // MARK: - Stats Bar (one card)
                    statsBar(posts: userVideos.count, followers: 0, following: 0, likes: 0)
                        .padding(.horizontal, 16)

                    // MARK: - Actions (2x2)
                    actionGrid
                        .padding(.horizontal, 16)

                    // MARK: - Appearance (compact)
                    appearanceCard
                        .padding(.horizontal, 16)

                    // MARK: - Videos Grid (keep yours, just tighter)
                    videosSection
                        .padding(.horizontal, 12)
                        .padding(.bottom, 22)
                }
            }
        }
        .task(id: authManager.currentUserId) { await loadUserVideos() }
        .onReceive(NotificationCenter.default.publisher(for: .profileShouldRefresh)) { _ in
            Task { await loadUserVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("VideoChanged"))) { _ in
            Task { await loadUserVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("LikeChanged"))) { _ in
            Task { await loadUserVideos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("CommentChanged"))) { _ in
            Task { await loadUserVideos() }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authManager)
                .environmentObject(service)
        }
        .alert("Upload Failed", isPresented: $showAvatarUploadError) {
            Button("OK", role: .cancel) { avatarUploadErrorMessage = nil }
        } message: {
            Text(avatarUploadErrorMessage ?? "An unknown error occurred while uploading your avatar.")
        }
    }

    // MARK: - Header
    private func profileHeader(username: String, displayName: String?, avatarURLString: String?) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {

                // Avatar + camera pick
                PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 68, height: 68)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(7)
                                    .background(Color.white.opacity(0.10), in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                    .offset(x: 4, y: 4)
                            }

                        if let avatarURL = avatarURLString, let url = URL(string: avatarURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Circle().fill(Color.white.opacity(0.06))
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    Circle().fill(Color.white.opacity(0.10))
                                @unknown default:
                                    Circle().fill(Color.white.opacity(0.10))
                                }
                            }
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                        } else {
                            Text(String(username.prefix(1)).uppercased())
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        if isUploadingAvatar {
                            ProgressView().tint(.white)
                        }
                    }
                }
                .onChange(of: selectedAvatarItem) { _, newItem in
                    Task { await uploadAvatarIfPossible(newItem) }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(username)")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    } else {
                        Text("Create your vibe • Post your first video")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Right controls (smaller + cleaner)
                HStack(spacing: 10) {
                    IconPill(system: "bell") { showNotifications = true }
                    IconPill(system: theme.isNeon ? "bolt.fill" : "sparkles") {
                        theme.setNeon(!theme.isNeon)
                    }
                }
            }

            // Primary actions row
            HStack(spacing: 10) {
                PrimaryPill(title: "Edit profile", system: "pencil") {
                    showEditProfile = true
                }
                SecondaryPill(title: "Copy token", system: "doc.on.doc") {
                    if let tok = AuthManager.shared.session?.accessToken {
                        UIPasteboard.general.string = tok
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                IconPill(system: "power") {
                    Task { await authManager.signOut() }
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color.vbPurple.opacity(0.28), Color.vbBlue.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: Color.vbBlue.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    // MARK: - Stats Bar
    private func statsBar(posts: Int, followers: Int, following: Int, likes: Int) -> some View {
        HStack {
            StatMini(title: "Posts", value: "\(posts)")
            Divider().opacity(0.12)
            StatMini(title: "Followers", value: "\(followers)")
            Divider().opacity(0.12)
            StatMini(title: "Following", value: "\(following)")
            Divider().opacity(0.12)
            StatMini(title: "Likes", value: "\(likes)")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Action Grid (2x2)
    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ActionTile(title: "Upload", system: "arrow.up.circle.fill", subtitle: "Post a vibe") {
                // Jump to Upload tab
                tabSelection?.binding.wrappedValue = .upload

                // Optional: haptic
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                // Optional: tell Upload screen to auto-open picker
                NotificationCenter.default.post(name: .init("OpenUploadPicker"), object: nil)
            }
            ActionTile(title: "Insights", system: "chart.bar.fill", subtitle: "Views & likes") {
                // TODO
            }
            ActionTile(title: "AI Tools", system: "sparkles", subtitle: "Create faster") {
                // TODO: jump to AI tab
            }
            ActionTile(title: "Settings", system: "gearshape.fill", subtitle: "Account & app") {
                // Navigate to settings
            }
        }
    }

    // MARK: - Appearance (compact)
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 10) {
                AppearancePill(title: "Classic", selected: appearanceSelection == "Classic") { appearanceSelection = "Classic" }
                AppearancePill(title: "Teal/Orange", selected: appearanceSelection == "Teal/Orange") { appearanceSelection = "Teal/Orange" }
                AppearancePill(title: "Lime/Magenta", selected: appearanceSelection == "Lime/Magenta") { appearanceSelection = "Lime/Magenta" }
            }

            HStack {
                Text("Glow")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(String(format: "%.2f", glowIntensity))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Slider(value: $glowIntensity, in: 0...1)
                .tint(.purple)
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Videos Section (minimal; keep your grid logic)
    private var videosSection: some View {
        Group {
            if isLoading {
                ProgressView().tint(.white).padding(.top, 20)
            } else if userVideos.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "film")
                        .font(.system(size: 38))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("No videos yet")
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Upload your first vibe and show the world.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .padding(.top, 6)
            } else {
                let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(userVideos) { video in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(colors: [Color.vbPurple.opacity(0.40), Color.vbBlue.opacity(0.40)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .aspectRatio(9/16, contentMode: .fit)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Data
    private func loadUserVideos() async {
        guard let userId = authManager.currentUserId?.uuidString else { return }
        print("[ProfileViewV3] loading videos for userId=\(userId)")
        isLoading = true
        defer { isLoading = false }
        do {
            let videos = try await service.fetchUserVideos(userId: userId)
            print("[ProfileViewV3] fetched \(videos.count) videos")
            userVideos = videos
        } catch {
            print("Error loading user videos: \(error)")
        }
    }

    private func uploadAvatarIfPossible(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let userId = authManager.currentUserId else { return }
        guard !isUploadingAvatar else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                isUploadingAvatar = true
                defer { isUploadingAvatar = false }

                let uploadData = resizeImageData(data, maxDimension: 1024, compressionQuality: 0.80) ?? data
                let url = try await service.uploadProfileImage(userId: userId, imageData: uploadData, contentType: "image/jpeg")

                await MainActor.run { authManager.profile?.avatar_url = url.absoluteString }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                NotificationCenter.default.post(name: .profileShouldRefresh, object: nil)
            }
        } catch {
            avatarUploadErrorMessage = String(describing: error)
            showAvatarUploadError = true
        }
    }
}

// MARK: - Small Components
private struct IconPill: View {
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryPill: View {
    let title: String
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: system)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryPill: View {
    let title: String
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: system)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ActionTile: View {
    let title: String
    let system: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 46, height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    Image(systemName: system)
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink, .blue],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                        .font(.system(size: 18, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.white).font(.headline)
                    Text(subtitle).foregroundStyle(.white.opacity(0.65)).font(.caption)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct StatMini: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(.white)
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppearancePill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.9))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selected ? Color.white : Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Resize Helper
private func resizeImageData(_ data: Data, maxDimension: CGFloat, compressionQuality: CGFloat) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let size = image.size
    let aspect = size.width / size.height
    var newSize: CGSize
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspect)
    } else {
        newSize = CGSize(width: maxDimension * aspect, height: maxDimension)
    }

    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard let final = resized else { return nil }
    return final.jpegData(compressionQuality: compressionQuality)
}
