import SwiftUI

struct ToolCard: View {
    var tool: AITool
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .frame(height: 88)
                .overlay(
                    Text(String(describing: tool))
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.system(size: 14, weight: .semibold))
                )
        }
        .buttonStyle(.plain)
    }
}

struct AIHubV2Modal: View {
    var tool: AITool
    var onClose: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("AIHubV2Modal")
                    .font(.title2.bold())
                Text("Selected tool: \(String(describing: tool))")
                    .foregroundStyle(.secondary)
                Button("Close", action: onClose)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("AI Hub")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
