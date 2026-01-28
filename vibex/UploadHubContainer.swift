import SwiftUI

/// Minimal placeholder for UploadHubContainer used by `AIFunnyV2Modal`.
/// Replace with the full upload hub implementation when available.
struct UploadHubContainer: View {
    let prefilledURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let url = prefilledURL {
                    Text("Ready to upload:")
                        .font(.headline)
                    Text(url.absoluteString)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else {
                    Text("No prefilled URL provided")
                        .foregroundColor(.secondary)
                }

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Upload Hub")
        }
    }
}

// Preview
#Preview {
    UploadHubContainer(prefilledURL: URL(string: "https://example.com/video.mp4"))
}
