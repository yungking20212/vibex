import SwiftUI

struct VibexAIChatView: View {
    let initialTool: VibeXAITool
    let initialUserMessage: String
    let autoSendOnAppear: Bool

    @State private var messages: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            List(messages, id: \.self) { msg in
                Text(msg)
                    .foregroundStyle(.primary)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let trimmed = initialUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if autoSendOnAppear, !trimmed.isEmpty {
                messages.append("You: \(trimmed)")
                // In a real implementation, you would kick off the AI response here.
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: initialTool.icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tool: \(initialTool.rawValue)")
                    .font(.headline)
                if !initialUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Initial: \(initialUserMessage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    // Replace `.chat` with any valid case available in your `VibeXAITool`.
    VibexAIChatView(
        initialTool: .chat,
        initialUserMessage: "Hello VibeX!",
        autoSendOnAppear: true
    )
}
