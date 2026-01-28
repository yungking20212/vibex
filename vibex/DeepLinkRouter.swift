import Foundation
import SwiftUI

final class DeepLinkRouter: ObservableObject {
    @Published var pendingURL: URL? = nil
    @Published var showProfile: Bool = false

    func handle(url: URL) {
        let path = url.path.lowercased()
        let host = url.host?.lowercased()
        if path.hasPrefix("/profile") || host == "profile" {
            pendingURL = url
            showProfile = true
            return
        }
        // Extend with more routes as needed
    }

    func reset() {
        pendingURL = nil
        showProfile = false
    }
}
