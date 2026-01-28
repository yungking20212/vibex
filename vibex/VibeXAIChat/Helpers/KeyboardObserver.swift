import SwiftUI
import Combine

final class KeyboardObserver: ObservableObject {
    // Initialize the publisher immediately to avoid usage-before-init errors
    let objectWillChange = ObservableObjectPublisher()

    @Published var height: CGFloat = 0

    #if os(iOS)
    private var showToken: NSObjectProtocol?
    private var hideToken: NSObjectProtocol?
    #endif

    init() {
        #if os(iOS)
        let center = NotificationCenter.default
        showToken = center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            guard let info = notification.userInfo,
                  let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            let frame = frameValue.cgRectValue
            withAnimation(.easeOut(duration: 0.25)) {
                self.height = frame.height
            }
        }

        hideToken = center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.height = 0
            }
        }
        #endif
    }

    deinit {
        #if os(iOS)
        let center = NotificationCenter.default
        if let t = showToken { center.removeObserver(t) }
        if let t = hideToken { center.removeObserver(t) }
        #endif
    }
}
