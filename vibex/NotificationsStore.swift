import Foundation
import SwiftUI
import Combine

struct AppNotification: Identifiable, Hashable {
    let id: UUID
    var title: String
    var message: String
    var date: Date
    var isRead: Bool

    init(id: UUID = UUID(), title: String, message: String, date: Date = .now, isRead: Bool = false) {
        self.id = id
        self.title = title
        self.message = message
        self.date = date
        self.isRead = isRead
    }
}

@MainActor
final class NotificationsStore: ObservableObject {
    static let shared = NotificationsStore()

    @Published private(set) var notifications: [AppNotification] = []

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    private init() {
        loadMock()
    }

    func loadMock() {
        notifications = [
            AppNotification(title: "New like", message: "@alex liked your video"),
            AppNotification(title: "New follower", message: "@jordan started following you"),
            AppNotification(title: "Comment", message: "\"Fire video!\" on your post", isRead: true),
            AppNotification(title: "Mention", message: "@sam mentioned you in a comment")
        ]
    }

    func refresh() async {
        // Simulate a refresh delay
        try? await Task.sleep(nanoseconds: 600_000_000)
        loadMock()
    }

    func markAllRead() {
        for idx in notifications.indices { notifications[idx].isRead = true }
        objectWillChange.send()
    }

    func toggleRead(_ id: UUID) {
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[idx].isRead.toggle()
        objectWillChange.send()
    }

    func delete(_ id: UUID) {
        notifications.removeAll { $0.id == id }
        objectWillChange.send()
    }
}

