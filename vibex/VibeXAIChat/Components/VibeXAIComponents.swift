import SwiftUI
import PhotosUI

// Tool chip
struct ToolChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.subheadline)
            Text(title).font(.subheadline).fontWeight(.semibold)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: isSelected || isHovering ? Color.white.opacity(0.10) : .clear, radius: isHovering ? 14 : 10, x: 0, y: 6)
        .opacity(isSelected ? 1.0 : 0.85)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHovering)
        #if os(macOS)
        .onHover { hovering in isHovering = hovering }
        #else
        .hoverEffect(.lift)
        #endif
    }
}

// Message row
struct MessageRow: View {
    let message: VibeXChatMessage
    let lastAnimatedID: String?

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Group {
                    if message.role == .assistant && message.id == lastAnimatedID { TypewriterText(fullText: message.text, shouldAnimate: true) }
                    else { Text(message.text) }
                }
                .font(.body).foregroundStyle(.white.opacity(isUser ? 0.98 : 0.94))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(bubbleBackground)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(isUser ? 0.12 : 0.10), lineWidth: 1))
                .contextMenu { Button { UIPasteboard.general.string = message.text } label: { Label("Copy", systemImage: "doc.on.doc") } }
                Text(timeString(message.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: some View {
        Group {
            if isUser { LinearGradient(colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.80)], startPoint: .topLeading, endPoint: .bottomTrailing).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)) }
            else { Color.white.opacity(0.08).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)) }
        }
    }

    private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date) }
}

// Typing bubble
struct TypingBubble: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Dot(delay: 0.0, phase: $phase)
                Dot(delay: 0.2, phase: $phase)
                Dot(delay: 0.4, phase: $phase)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            Spacer()
        }
        .onAppear { withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { phase = 1 } }
    }

    private struct Dot: View {
        let delay: Double
        @Binding var phase: CGFloat

        var body: some View {
            Circle()
                .frame(width: 7, height: 7)
                .opacity(0.35 + 0.55 * wave)
                .scaleEffect(0.85 + 0.35 * wave)
        }

        private var wave: CGFloat {
            let x = (phase + CGFloat(delay)).truncatingRemainder(dividingBy: 1)
            return x < 0.5 ? x * 2 : (1 - x) * 2
        }
    }
}

// Thinking pill
struct ThinkingPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.85)
            Text("Thinking")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// Quick pill
struct QuickPill: View {
    let title: String
    let action: () -> Void
    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHovering)
        #if os(macOS)
        .onHover { hovering in isHovering = hovering }
        #else
        .hoverEffect(.automatic)
        #endif
    }
}

// Error banner
struct ErrorBanner: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
            Button("Retry", action: retry)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(12)
        .foregroundStyle(.white.opacity(0.95))
        .background(Color.red.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// Attachments UI
struct AttachmentsRow: View {
    @Binding var attachments: [VibeXAttachment]
    let onRemove: (UUID) -> Void
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var videoItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) { pill(icon: "photo.fill", title: "Image") }
                PhotosPicker(selection: $videoItem, matching: .videos) { pill(icon: "video.fill", title: "Video") }
                Spacer()
                if !attachments.isEmpty { Text("\(attachments.count) attached").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7)) }
            }
            .padding(.horizontal, 12)

            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { att in
                            AttachmentChip(att: att) { onRemove(att.id) }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in guard let newItem else { return }; Task { await addImage(from: newItem) } }
        .onChange(of: videoItem) { _, newItem in guard let newItem else { return }; Task { await addVideo(from: newItem) } }
    }

    private func pill(icon: String, title: String) -> some View { HStack(spacing: 8) { Image(systemName: icon); Text(title) }.font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9)).padding(.horizontal, 12).padding(.vertical, 10).background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)) }

    private func addImage(from item: PhotosPickerItem) async { do { guard let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else { return }; attachments.append(.init(kind: .image, filename: "image.jpg", data: data, previewImage: ui)) } catch { } }

    private func addVideo(from item: PhotosPickerItem) async { do { guard let data = try await item.loadTransferable(type: Data.self) else { return }; attachments.append(.init(kind: .video, filename: "video.mov", data: data, previewImage: nil)) } catch { } }
}

struct AttachmentChip: View {
    let att: VibeXAttachment
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let img = att.previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: att.kind == .video ? "video.fill" : "paperclip")
                    .frame(width: 34, height: 34)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(att.kind == .video ? "Video" : "Image")
                    .font(.caption.weight(.semibold))
                Text(att.filename)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.9))
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(10)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// Typewriter
struct TypewriterText: View {
    let fullText: String
    let shouldAnimate: Bool
    @State private var visibleCount: Int = 0

    var body: some View {
        Text(String(fullText.prefix(visibleCount)))
            .onAppear {
                guard shouldAnimate else {
                    visibleCount = fullText.count
                    return
                }
                visibleCount = 0
                Task {
                    for i in 1...fullText.count {
                        visibleCount = i
                        try? await Task.sleep(nanoseconds: 8_000_000)
                    }
                }
            }
    }
}

// Agent memory chips and editor
struct AgentMemoryChips: View {
    @Binding var memory: AgentMemory
    var onEdit: () -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MemoryChip(text: "Style: \(memory.savedStyle)")
                MemoryChip(text: "Voice: \(memory.myVoice)")
                MemoryChip(text: "Tone: \(memory.brandTone)")
                Button(action: onEdit) { HStack(spacing: 8) { Image(systemName: "pencil"); Text("Edit") }.font(.subheadline).fontWeight(.semibold).padding(.horizontal, 12).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule()) }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }

    private struct MemoryChip: View { let text: String; var body: some View { Text(text).font(.caption).fontWeight(.semibold).padding(.horizontal, 10).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)) } }
}

struct MemoryEditor: View {
    @Binding var memory: AgentMemory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Saved Style")) {
                    TextField("e.g. Clean & Next-Gen", text: $memory.savedStyle)
                }
                Section(header: Text("My Voice")) {
                    TextField("e.g. Confident, short, punchy", text: $memory.myVoice)
                }
                Section(header: Text("Brand Tone")) {
                    TextField("e.g. Premium, futuristic, viral", text: $memory.brandTone)
                }
            }
            .navigationTitle("Agent Memory")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
