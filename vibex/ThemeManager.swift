import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // Required publisher for ObservableObject conformance
    let objectWillChange = ObservableObjectPublisher()

    @AppStorage("vibex_theme") private var selected: String = "neon" {
        willSet { objectWillChange.send() }
    }

    var isNeon: Bool { selected == "neon" }

    func setNeon(_ neon: Bool) {
        selected = neon ? "neon" : "luxury"
        objectWillChange.send()
    }
}
