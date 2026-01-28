import SwiftUI
import Combine

import SwiftUI
import Combine

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NotificationsStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if store.notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("No notifications yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text("Pull to refresh")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.top, 40)
                } else {
                    List {
                        ForEach(store.notifications) { note in
                            NotificationRow(note: note,
                                            onDelete: { store.delete(note.id) },
                                            onToggleRead: { store.toggleRead(note.id) })
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await store.refresh()
                    }
                    .task {
                        if store.notifications.isEmpty {
                            await store.refresh()
                        }
                    }
                    .animation(.snappy, value: store.notifications)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.unreadCount > 0 {
                        Button {
                            #if os(iOS)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                            store.markAllRead()
                        } label: {
                            Image(systemName: "checkmark.seal.fill")
                        }
                        .accessibilityLabel("Mark all as read")
                    }
                }
            }
        }
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
            .preferredColorScheme(.dark)
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let note: AppNotification
    let onDelete: () -> Void
    let onToggleRead: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(note.isRead ? Color.white.opacity(0.08) : Color.yellow.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(note.isRead ? Color.white.opacity(0.12) : Color.yellow.opacity(0.35), lineWidth: 1)
                    )
                Image(systemName: note.isRead ? "bell" : "bell.badge.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(note.isRead ? .white.opacity(0.7) : .yellow)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(note.date, style: .time)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Text(note.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.isRead ? "Read" : "Unread") notification. \(note.title). \(note.message)")
        .accessibilityValue(note.isRead ? "Read" : "Unread")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button { onToggleRead() } label: {
                Label(note.isRead ? "Mark as unread" : "Mark as read", systemImage: note.isRead ? "envelope.badge" : "envelope.open")
            }
            .tint(.blue)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleRead()
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
        }
    }
}
