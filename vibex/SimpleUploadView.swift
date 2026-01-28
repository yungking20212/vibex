import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import UIKit
import UniformTypeIdentifiers
import Supabase

struct SimpleUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tabSelection) private var tabSelection
    @EnvironmentObject var draftStore: DraftStore
    @EnvironmentObject var auth: AuthManager

    @StateObject private var uploader = SupabaseVideoUploader()

    @State private var pickerItem: PhotosPickerItem?
    @State private var showPHPicker: Bool = false
    @State private var pickedURL: URL?
    @State private var previewTempURL: URL? = nil
    @State private var previewImage: UIImage?
    @State private var showPreview: Bool = false
    @State private var previewScale: CGFloat = 0.96
    @State private var player: AVPlayer?
    @State private var showPlayer: Bool = false
    @State private var captionLimit: Int = 150
    @State private var showUploadSuccessToast: Bool = false
    @State private var showFinalizeSuccessToast: Bool = false
    @State private var showFileTooLargeAlert: Bool = false
    @State private var showListAlert: Bool = false
    @State private var listAlertMessage: String = ""

    @State private var targetQuality: VideoQuality = .p1080

    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    LogoBadge(size: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upload")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Share your vibe — quick, beautiful uploads")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()
                }
                .padding(.horizontal, 28)

                // Picker / Preview
                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    if let img = previewImage, showPreview {
                        Button {
                            if let url = pickedURL {
                                player = AVPlayer(url: url)
                                // Debug: log file existence and path when opening preview
                                let exists = FileManager.default.fileExists(atPath: url.path)
                                print("[UploadPreview] opening player for url=\(url.absoluteString), exists=\(exists)")
                                showPlayer = true
                            }
                        } label: {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipped()
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 6)
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.white.opacity(0.95))
                                        .shadow(radius: 6)
                                )
                                .padding(.horizontal, 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.vbGlow.opacity(0.22), lineWidth: 1)
                                        .blendMode(.screen)
                                )
                                .scaleEffect(previewScale)
                                .opacity(showPreview ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showPreview)
                                .accessibilityIdentifier("previewPlayButton")
                        }
                    } else if pickedURL != nil && previewImage == nil {
                        // While thumbnail is being generated show a subtle loader — no gradient placeholder
                        ProgressView()
                            .tint(.white)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .cornerRadius(14)
                            .padding(.horizontal, 28)
                            .shimmer()
                    } else if pickedURL != nil {
                        // If picked but no preview image (fallback), show a simple play card without gradient placeholder
                        Button {
                            if let url = pickedURL {
                                player = AVPlayer(url: url)
                                let exists = FileManager.default.fileExists(atPath: url.path)
                                print("[UploadPreview] opening player (fallback) for url=\(url.absoluteString), exists=\(exists)")
                                showPlayer = true
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.black.opacity(0.22))
                                            .frame(height: 220)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color.vbGlow.opacity(0.12), lineWidth: 1)
                                            )

                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.95))
                            }
                            .padding(.horizontal, 28)
                            .accessibilityIdentifier("fallbackPlayButton")
                        }
                    } else {
                        HStack(spacing: 12) {
                            LogoBadge(size: 36)
                            Text("Choose Video")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .accessibilityIdentifier("chooseVideoButton")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(14)
                        .padding(.horizontal, 28)
                        .shadow(color: Color.vbBlue.opacity(0.25), radius: 12, x: 0, y: 8)
                    }
                }
                .onChange(of: pickerItem) { _, item in
                    guard let item else {
                        // cleared
                        pickedURL = nil
                        previewImage = nil
                        showPreview = false
                        return
                    }

                    Task {
                        do {
                            let url = try await item.loadVideoFileURL()
                            // copy to a safe temp preview location
                            let tmp = try copyToPreviewTemp(url: url, previous: previewTempURL)
                            previewTempURL = tmp
                            pickedURL = tmp
                            previewImage = nil
                            showPreview = false

                            if let img = await generateThumbnail(from: tmp) {
                                // animate entrance
                                previewImage = img
                                previewScale = 0.96
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showPreview = true
                                    previewScale = 1.0
                                }
                            }
                        } catch {
                            print("[UploadPreview] failed to load or copy picked video: \(error)")
                        }
                    }
                }
                // Full screen player
                .fullScreenCover(isPresented: $showPlayer, onDismiss: {
                    player?.pause()
                    player = nil
                }) {
                    if let av = player {
                        PlayerFullScreenView(player: av)
                    } else {
                        EmptyView()
                    }
                }

                // Caption editor with glass feel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Caption")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        if !draftStore.captionDraft.isEmpty {
                            Button {
                                draftStore.captionDraft = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .accessibilityIdentifier("clearCaptionButton")
                            .disabled(uploader.isUploading)
                        }
                    }

                    Text("\(max(0, captionLimit - draftStore.captionDraft.count)) characters left")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))

                    TextEditor(text: $draftStore.captionDraft)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)
                        .opacity(uploader.isUploading ? 0.6 : 1.0)
                        .disabled(uploader.isUploading)
                        .accessibilityIdentifier("captionEditor")
                        .onChange(of: draftStore.captionDraft) { _, newValue in
                            if newValue.count > captionLimit {
                                draftStore.captionDraft = String(newValue.prefix(captionLimit))
                            }
                        }
                }
                .padding(.horizontal, 28)

                HStack(spacing: 12) {
                    Text("Quality")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                    Picker("Quality", selection: $targetQuality) {
                        Text("1080p").tag(VideoQuality.p1080)
                        Text("4K").tag(VideoQuality.p4k)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 28)

                // Upload button
                Button {
                    if uploader.isUploading { return }
                    guard let pickedURL, let userId = auth.currentUserId else { return }
                    // Use a conservative max size to avoid client/storage limits
                    if !isFileSizeAcceptable(pickedURL, maxMB: 500) {
                        showFileTooLargeAlert = true
                        return
                    }
                    Task {
                        let _ = await uploader.uploadVideoFile(fileURL: pickedURL, caption: draftStore.captionDraft, userId: userId)
                        if uploader.errorText == nil {
                            withAnimation(.spring(duration: 0.35)) { showUploadSuccessToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation(.easeInOut(duration: 0.3)) { showUploadSuccessToast = false }
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                            // Notify profile to refresh and reset local state
                            NotificationCenter.default.post(name: .profileShouldRefresh, object: nil)
                            self.pickerItem = nil
                            if let tmp = previewTempURL {
                                try? FileManager.default.removeItem(at: tmp)
                                previewTempURL = nil
                            }
                            self.pickedURL = nil
                            self.previewImage = nil
                            self.showPreview = false
                            self.player = nil
                            self.showPlayer = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                tabSelection?.binding.wrappedValue = .feed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    tabSelection?.binding.wrappedValue = .profile
                                }
                            }
                            draftStore.captionDraft = ""
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(uploader.isUploading ? "Uploading..." : "Upload")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 28)
                    .neonGlow()
                    .accessibilityIdentifier("uploadButton")
                }
                .disabled(pickedURL == nil || uploader.isUploading)

                // Quick test upload button (uploads a small text file to storage)
                Button {
                    if uploader.isUploading { return }
                    Task { await uploadTestFile() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane")
                        Text("Test Upload")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 28)
                }
                .disabled(uploader.isUploading)

                // List files in the authenticated user's folder for debugging
                Button {
                    if uploader.isUploading { return }
                    Task { await listUserFiles() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tray.full")
                        Text("List Files")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 28)
                }
                .disabled(uploader.isUploading)

                if uploader.isUploading {
                    ProgressView(value: uploader.progress, total: 1.0) {
                        Text("Uploading")
                            .foregroundColor(.white.opacity(0.8))
                    } currentValueLabel: {
                        Text(String(format: "%.0f%%", min(100, max(0, uploader.progress * 100))))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .tint(Color.vbPink)
                    .padding(.horizontal, 28)
                    .accessibilityIdentifier("uploadProgressView")
                }

                // Error / Retry / Cancel actions
                if let error = uploader.errorText {
                    // Haptic for error
                    let _ = {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        return 0
                    }()
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        HStack(spacing: 12) {
                            Button {
                                uploader.cancel()
                            } label: {
                                Text("Cancel")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("cancelUploadButton")

                            Button {
                                Task { _ = await uploader.retry() }
                            } label: {
                                Text("Retry Upload")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("retryUploadButton")

                            Button {
                                Task { await uploader.retryInsert() }
                            } label: {
                                Text("Finalize Metadata")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("finalizeMetadataButton")
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 28)

            // Next‑Gen uploading overlay
            if uploader.isUploading {
                NextGenUploadingView(progress: Binding(get: { uploader.progress }, set: { uploader.progress = $0 }))
                    .transition(.scale.combined(with: .opacity))
            }

            if showUploadSuccessToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    Text("Upload complete").foregroundStyle(.white).font(.subheadline).bold()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            if showFinalizeSuccessToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    Text("Metadata saved").foregroundStyle(.white).font(.subheadline).bold()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .onDisappear {
            uploader.cancel()
            if let tmp = previewTempURL {
                try? FileManager.default.removeItem(at: tmp)
                previewTempURL = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenUploadPicker"))) { _ in
            // Present a programmatic PHPicker when requested
            showPHPicker = true
        }
        .fullScreenCover(isPresented: $showPHPicker) {
            PHPickerViewControllerWrapper { url in
                showPHPicker = false
                guard let url else { return }
                // Mirror the existing PhotosPicker behavior
                Task {
                    do {
                        let tmp = try copyToPreviewTemp(url: url, previous: previewTempURL)
                        previewTempURL = tmp
                        pickedURL = tmp
                        previewImage = nil
                        showPreview = false

                        if let img = await generateThumbnail(from: tmp) {
                            previewImage = img
                            previewScale = 0.96
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                showPreview = true
                                previewScale = 1.0
                            }
                        }
                    } catch {
                        print("[UploadPreview] failed to copy PHPicker file to preview temp: \(error)")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("File Too Large", isPresented: $showFileTooLargeAlert) {
            Button("OK", role: .cancel) { showFileTooLargeAlert = false }
        } message: {
            Text("The selected video exceeds the 50MB limit. Please choose a smaller file or compress to 1080p.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .metadataFinalizeSucceeded)) { _ in
            withAnimation(.spring()) {
                showFinalizeSuccessToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.3)) { showFinalizeSuccessToast = false }
            }
        }
        .alert("Files", isPresented: $showListAlert) {
            Button("OK", role: .cancel) { showListAlert = false }
        } message: {
            Text(listAlertMessage)
        }
    }
}

// MARK: - File size validation

private func isFileSizeAcceptable(_ url: URL, maxMB: Int = 500) -> Bool {
    do {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? NSNumber {
            let mb = size.int64Value / (1024 * 1024)
            return mb <= maxMB
        }
    } catch { }
    return false
}

// MARK: - Quick test upload helper

extension SimpleUploadView {
    private func uploadTestFile() async {
        uploader.errorText = nil
        uploader.isUploading = true
        uploader.progress = 0
        defer { uploader.isUploading = false }

        do {
            let client = SupabaseConfig.shared.client
            let data = "hello".data(using: .utf8)!
            let fileName = "test-\(UUID().uuidString).txt"
            let path = "test-uploads/\(fileName)"

            // Upload using the app's Supabase client (requires authenticated user or permissive policy)
            _ = try await client.storage
                .from(SupabaseConfig.bucketVideos)
                .upload(path: path, file: data, options: FileOptions(contentType: "text/plain", upsert: false))

            uploader.progress = 1.0

            // Attempt to fetch a public URL (may be nil for private buckets)
            let publicURL = try client.storage.from(SupabaseConfig.bucketVideos).getPublicURL(path: path)
            print("Test upload public URL: \(publicURL.absoluteString)")
            withAnimation(.spring()) { showUploadSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.3)) { showUploadSuccessToast = false }
            }
        } catch {
            uploader.errorText = error.localizedDescription
        }
    }

    private func listUserFiles() async {
        uploader.errorText = nil
        guard let userId = auth.currentUserId else {
            listAlertMessage = "Not signed in"
            showListAlert = true
            return
        }

        do {
            let client = SupabaseConfig.shared.client
            let list = try await client.storage.from(SupabaseConfig.bucketVideos).list(path: userId.uuidString)
            let names = list.map { $0.name }
            let preview = names.prefix(10).joined(separator: "\n")
            listAlertMessage = "Found \(names.count) items.\n\n\(preview)"
            print("[Uploader] listUserFiles: count=\(names.count)\n\(preview)")
            showListAlert = true
        } catch {
            print("[Uploader] listUserFiles failed: \(error)")
            listAlertMessage = "List failed: \(error.localizedDescription)"
            showListAlert = true
        }
    }
}

// Compression is handled by `SupabaseVideoUploader` using the shared `VideoQuality` enum.

// MARK: - Thumbnail generation

@MainActor
private func generateThumbnail(from url: URL) async -> UIImage? {
    await withCheckedContinuation { cont in
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 1080, height: 1920)

        let time = CMTime(seconds: 0.8, preferredTimescale: 600)
        Task {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                cont.resume(returning: uiImage)
            } catch {
                cont.resume(returning: nil)
            }
        }
    }
}

// Copy a picked video to a dedicated preview temp file and remove the previous preview temp if present.
private func copyToPreviewTemp(url: URL, previous: URL?) throws -> URL {
    let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    try FileManager.default.copyItem(at: url, to: tmp)
    if let prev = previous, prev.path != tmp.path {
        try? FileManager.default.removeItem(at: prev)
    }
    return tmp
}

// MARK: - PHPicker wrapper for programmatic presentation
struct PHPickerViewControllerWrapper: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present the PHPicker only once when the VC appears
        if context.coordinator.didPresent { return }
        context.coordinator.didPresent = true

        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator

        uiViewController.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PHPickerViewControllerWrapper
        var didPresent = false

        init(_ parent: PHPickerViewControllerWrapper) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let first = results.first else {
                parent.onPick(nil)
                return
            }

            let provider = first.itemProvider
            let movieType = UTType.movie.identifier

            if provider.hasItemConformingToTypeIdentifier(movieType) {
                provider.loadFileRepresentation(forTypeIdentifier: movieType) { url, error in
                    guard let url else {
                        DispatchQueue.main.async { self.parent.onPick(nil) }
                        return
                    }
                    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                    do {
                        try FileManager.default.copyItem(at: url, to: tmp)
                        DispatchQueue.main.async { self.parent.onPick(tmp) }
                    } catch {
                        DispatchQueue.main.async { self.parent.onPick(nil) }
                    }
                }
            } else {
                parent.onPick(nil)
            }
        }
    }
}

// MARK: - Full screen player

struct PlayerFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    let player: AVPlayer

    @State private var didStart = false
    @State private var showError = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: player)
                .ignoresSafeArea()

            Button(action: {
                player.pause()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(18)
        }
        .onAppear {
            player.play()
            // Poll briefly to detect playback start or failure
            Task {
                let start = Date()
                while Date().timeIntervalSince(start) < 3.0 {
                    if player.timeControlStatus == .playing {
                        didStart = true
                        break
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                if !didStart {
                    // If still not playing, mark error so UI can show a helpful message
                    showError = true
                    print("[PlayerFullScreenView] playback did not start; timeControlStatus=\(player.timeControlStatus.rawValue)")
                }
            }
        }
        .onDisappear { player.pause() }
        .overlay(
            Group {
                if showError {
                    VStack(spacing: 12) {
                        Text("Playback failed")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("The video couldn't start. The file may be missing or unsupported.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                        HStack(spacing: 12) {
                            Button("Retry") {
                                showError = false
                                didStart = false
                                player.seek(to: .zero)
                                player.play()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Close") {
                                player.pause(); dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding()
                }
            }
        )
    }
}

// Notifications are defined centrally in ContentView.swift

// Preview
#if DEBUG
struct SimpleUploadView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleUploadView()
            .environmentObject(DraftStore())
            .environmentObject(AuthManager.shared)
            .preferredColorScheme(.dark)
    }
}
#endif

