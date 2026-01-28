import Foundation
import Combine

@MainActor
final class DraftStore: ObservableObject {
    @Published var captionDraft: String = ""
}
