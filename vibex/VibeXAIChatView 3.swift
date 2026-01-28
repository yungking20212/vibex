import SwiftUI
import Foundation

struct AIMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
    var date: Date = Date()
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIMessage] = [
        AIMessage(role: .assistant, text: "Welcome to VibeX AI. How can I help you create today?")
    ]
    @Published var input: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String? = nil

    private let service: AIChatService

    init(service: AIChatService? = nil) {
        if let service = service {
            self.service = service
        } else {
            let url = URL(string: "https://jnkzbfqrwkgfiyxvwrug.supabase.co/functions/v1/vibex-ai-chat")!
            self.service = ProductionChatService(endpoint: url)
        }
    }

    func send() async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        input = ""
        errorMessage = nil
        let userMsg = AIMessage(role: .user, text: trimmed)
        messages.append(userMsg)
        isSending = true
        defer { isSending = false }

        do {
            let requestMessages: [AIChatRequestMessage] = messages.map { msg in
                let role: String = (msg.role == .user) ? "user" : "assistant"
                return AIChatRequestMessage(role: role, content: msg.text)
            }
            let reply = try await service.send(messages: requestMessages)
            messages.append(AIMessage(role: .assistant, text: reply))
        } catch let error as AIChatError {
            errorMessage = error.localizedDescription
            messages.append(AIMessage(role: .assistant, text: error.localizedDescription))
        } catch {
            errorMessage = error.localizedDescription
            messages.append(AIMessage(role: .assistant, text: "Something went wrong. Please try again."))
        }
    }
}

struct VibeXAIChatView_Preview: View {
    @StateObject private var model = AIChatViewModel()
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.08))
                messagesList
                if let err = model.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
                inputBar
            }
            .padding(.bottom, keyboardHeight)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        }
        .onTapGesture { isFocused = false }
        .onReceive(Publishers.keyboardHeight) { height in
            keyboardHeight = height
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 36, height: 36)
                Image(systemName: "sparkles").foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("VibeX AI").font(.headline).foregroundStyle(.white)
                Text("Create the vibe with AI").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button {
                // TODO: settings
            } label: {
                Image(systemName: "slider.horizontal.3").foregroundStyle(.white)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: model.messages.count) { _ in
                if let last = model.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: AIMessage) -> some View {
        HStack {
            if msg.role == .assistant { spacerUser() }
            VStack(alignment: .leading, spacing: 6) {
                Text(msg.text)
                    .foregroundStyle(.white)
                    .font(.body)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(msg.role == .user ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if msg.role == .user { spacerAssistant() }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func spacerUser() -> some View { Spacer(minLength: 40) }
    private func spacerAssistant() -> some View { Spacer(minLength: 40) }

    private var inputBar: some View {
        VStack(spacing: 8) {
            Divider().background(Color.white.opacity(0.08))
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $model.input)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.06))
                    .foregroundColor(.white)
                    .frame(minHeight: 38, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isFocused)

                Button(action: { Task { await model.send() } }) {
                    Image(systemName: model.isSending ? "hourglass" : "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(model.isSending)
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.001))
        }
        .background(.ultraThinMaterial.opacity(0.15))
    }
}

// MARK: - Keyboard Height Publisher

import Combine
import UIKit

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { $0.keyboardHeight }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        return MergeMany(willShow, willHide)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

private extension Notification {
    var keyboardHeight: CGFloat {
        (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

#Preview {
    VibeXAIChatView_Preview()
        .preferredColorScheme(.dark)
}
