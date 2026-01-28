//
//  SettingsView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/25/26.
//

import SwiftUI
import Auth
import MessageUI
import SafariServices
import WebKit

extension Notification.Name {
    static let privacySettingsDidChange = Notification.Name("vb.privacySettingsDidChange")
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var service: SupabaseService
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSection: SettingsSection?
    @State private var showSignOutConfirmation = false
    private let preselectedSection: SettingsSection?
    private let viewAsUserIdOverride: UUID?

    init(preselectedSection: SettingsSection? = nil, viewAsUserIdOverride: UUID? = nil) {
        self.preselectedSection = preselectedSection
        self.viewAsUserIdOverride = viewAsUserIdOverride
        _selectedSection = State(initialValue: preselectedSection)
    }
    
    private var isOwner: Bool {
        // Honor an optional view-as override when provided; otherwise use current authManager user id
        let effective = viewAsUserIdOverride?.uuidString ?? authManager.currentUserId?.uuidString
        return effective == "64c13e5b-04fe-493a-b030-a7d332bd3600"
    }
    
    enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
        case account = "Account"
        case appearance = "Appearance"
        case notifications = "Notifications"
        case privacy = "Privacy & Safety"
        case accessibility = "Accessibility"
        case dataStorage = "Data & Storage"
        case about = "About"
        case help = "Help & Support"
        case admin = "Admin Tools"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .account: return "person.circle.fill"
            case .appearance: return "paintbrush.fill"
            case .notifications: return "bell.fill"
            case .privacy: return "lock.shield.fill"
            case .accessibility: return "accessibility"
            case .dataStorage: return "internaldrive.fill"
            case .about: return "info.circle.fill"
            case .help: return "questionmark.circle.fill"
            case .admin: return "lock.shield"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.vbBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.primaryNeon)
                                    .frame(width: 80, height: 80)
                                    .neonGlow(intensity: theme.isNeon ? 1.0 : 0.3)
                                
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("Settings")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("Customize your VibeX experience")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Settings Sections
                        VStack(spacing: 12) {
                            let allSections = SettingsSection.allCases
                            let sectionsToShow: [SettingsSection] = isOwner ? allSections : allSections.filter { $0 != .admin }
                            ForEach(sectionsToShow, id: \.self) { section in
                                NavigationLink(tag: section, selection: $selectedSection) {
                                    settingsDetailView(for: section)
                                } label: {
                                    SettingsRow(
                                        icon: section.icon,
                                        title: section.rawValue,
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Sign Out Button
                        Button {
                            showSignOutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Version Info
                        VStack(spacing: 4) {
                            Text("VibeX")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("Version 1.0.0 (Build 1)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    @ViewBuilder
    private func settingsDetailView(for section: SettingsSection) -> some View {
        switch section {
        case .account:
            AccountSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .notifications:
            NotificationSettingsView()
        case .privacy:
            PrivacySettingsView()
                .environmentObject(authManager)
        case .accessibility:
            AccessibilitySettingsView()
        case .dataStorage:
            DataStorageSettingsView()
        case .about:
            AboutSettingsView()
        case .help:
            HelpSupportView()
        case .admin:
            AdminToolsView()
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var service: SupabaseService
    @State private var showDeleteConfirmation = false
    @State private var editingProfile = false
    @State private var newDisplayName: String = ""
    @State private var newUsername: String = ""
    @State private var isSavingProfile = false
    @State private var showSaveResult = false
    @State private var saveResultMessage = ""
    
    private var isOnlineNow: Bool {
        // Consider user online if there is an active session. Replace with realtime presence when available.
        return authManager.session != nil
    }
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Profile Information") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isOnlineNow ? Color.green : Color.gray)
                                .frame(width: 10, height: 10)
                            Text(isOnlineNow ? "Online" : "Offline")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        SettingsRow(
                            icon: "person.text.rectangle",
                            title: "Username",
                            subtitle: "@\(authManager.profile?.username ?? "username")"
                        )
                        
                        SettingsRow(
                            icon: "envelope.fill",
                            title: "Email",
                            subtitle: authManager.session?.user.email ?? "Not available"
                        )
                        
                        SettingsRow(
                            icon: "calendar",
                            title: "Member Since",
                            subtitle: formatDate(authManager.profile?.created_at)
                        )
                        
                        SettingsRow(
                            icon: isOnlineNow ? "circle.inset.filled" : "circle",
                            title: "Status",
                            subtitle: isOnlineNow ? "Online" : "Offline"
                        )
                        
                        if editingProfile {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Edit Profile Info")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.8))

                                VStack(spacing: 10) {
                                    TextField("Display name", text: $newDisplayName)
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .padding(10)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    TextField("Username", text: $newUsername)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .padding(10)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        editingProfile = false
                                    } label: {
                                        Text("Cancel")
                                            .frame(maxWidth: .infinity)
                                            .padding(10)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }

                                    Button {
                                        Task { await saveProfileEdits() }
                                    } label: {
                                        HStack {
                                            if isSavingProfile { ProgressView().tint(.white) }
                                            Text(isSavingProfile ? "Saving..." : "Save")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(Color.purple.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .disabled(isSavingProfile || newUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            Button {
                                newDisplayName = authManager.profile?.display_name ?? ""
                                newUsername = authManager.profile?.username ?? ""
                                withAnimation { editingProfile = true }
                            } label: {
                                SettingsRow(
                                    icon: "pencil",
                                    title: "Edit Profile Info",
                                    subtitle: "Display name and username",
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    SettingsSection(title: "Account Actions") {
                        NavigationLink {
                            ChangePasswordView()
                        } label: {
                            SettingsRow(
                                icon: "key.fill",
                                title: "Change Password",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ChangeEmailView(currentEmail: authManager.session?.user.email ?? "")
                        } label: {
                            SettingsRow(
                                icon: "envelope.badge",
                                title: "Change Email",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    SettingsSection(title: "Danger Zone") {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            SettingsRow(
                                icon: "trash.fill",
                                title: "Delete Account",
                                subtitle: "Permanently delete your account and data"
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Implement account deletion
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Profile Update", isPresented: $showSaveResult) {
            Button("OK", role: .cancel) { showSaveResult = false }
        } message: {
            Text(saveResultMessage)
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func saveProfileEdits() async {
        guard !isSavingProfile else { return }
        let display = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else { return }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            guard let userId = authManager.currentUserId else {
                await MainActor.run {
                    saveResultMessage = "Unable to determine user id"
                    showSaveResult = true
                }
                return
            }

            let updated = try await service.updateProfile(
                userId: userId,
                username: user,
                displayName: display,
                bio: authManager.profile?.bio
            )

            await MainActor.run {
                authManager.profile = updated
                saveResultMessage = "Your profile info was updated."
                showSaveResult = true
                withAnimation { editingProfile = false }
            }
        } catch {
            await MainActor.run {
                saveResultMessage = error.localizedDescription
                showSaveResult = true
            }
        }
    }
}

// MARK: - Change Password

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSaving = false
    @State private var showResult = false
    @State private var resultMessage = ""

    private var canSave: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                ScrollView {
                    VStack(spacing: 16) {
                        SettingsSection(title: "Change Password") {
                            VStack(spacing: 12) {
                                SecureField("Current password", text: $currentPassword)
                                    .textContentType(.password)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                SecureField("New password (min 8 chars)", text: $newPassword)
                                    .textContentType(.newPassword)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                SecureField("Confirm new password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    Task { await save() }
                                } label: {
                                    HStack {
                                        if isSaving { ProgressView().tint(.white) }
                                        Text(isSaving ? "Saving..." : "Update Password")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(canSave ? Color.purple.opacity(0.6) : Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .disabled(!canSave || isSaving)

                                Text("Password must be at least 8 characters.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }
            )
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Password Update", isPresented: $showResult) {
                Button("OK", role: .cancel) { if resultMessage.contains("success") { dismiss() } }
            } message: { Text(resultMessage) }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            // TODO: Integrate with your auth layer to change password.
            // Example:
            // try await authManager.changePassword(current: currentPassword, new: newPassword)
            try await Task.sleep(nanoseconds: 300_000_000) // Simulate work
            await MainActor.run {
                resultMessage = "Password change success."
                showResult = true
            }
        } catch {
            await MainActor.run {
                resultMessage = error.localizedDescription
                showResult = true
            }
        }
    }
}

// MARK: - Change Email

struct ChangeEmailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    let currentEmail: String

    @State private var newEmail: String = ""
    @State private var password: String = ""
    @State private var isSaving = false
    @State private var showResult = false
    @State private var resultMessage = ""

    private var canSave: Bool {
        !newEmail.isEmpty && newEmail.contains("@") && !password.isEmpty
    }

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                ScrollView {
                    VStack(spacing: 16) {
                        SettingsSection(title: "Change Email") {
                            VStack(alignment: .leading, spacing: 12) {
                                SettingsRow(icon: "envelope.fill", title: "Current Email", subtitle: currentEmail)

                                TextField("New email", text: $newEmail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                SecureField("Password (for verification)", text: $password)
                                    .textContentType(.password)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    Task { await save() }
                                } label: {
                                    HStack {
                                        if isSaving { ProgressView().tint(.white) }
                                        Text(isSaving ? "Saving..." : "Update Email")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(canSave ? Color.purple.opacity(0.6) : Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .disabled(!canSave || isSaving)

                                Text("You may be asked to verify the new email.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding()
                }
            )
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Email Update", isPresented: $showResult) {
                Button("OK", role: .cancel) { if resultMessage.contains("success") { dismiss() } }
            } message: { Text(resultMessage) }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            // TODO: Integrate with your auth layer to change email.
            // Example:
            // try await authManager.changeEmail(password: password, newEmail: newEmail)
            try await Task.sleep(nanoseconds: 300_000_000) // Simulate work
            await MainActor.run {
                resultMessage = "Email change success."
                showResult = true
            }
        } catch {
            await MainActor.run {
                resultMessage = error.localizedDescription
                showResult = true
            }
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @AppStorage("vb.selectedColorScheme") private var selectedScheme: String = "Purple & Blue"
    @AppStorage("vb.glowIntensity") private var storedGlowIntensity: Double = 1.0
    @State private var glowIntensity: Double = 1.0
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
                .onAppear {
                    glowIntensity = storedGlowIntensity
                }
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Preview") {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 120)
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(LinearGradient.primaryNeon)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .purple.opacity(glowIntensity), radius: 20, x: 0, y: 0)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(selectedScheme)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Glow: \(Int(glowIntensity * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    SettingsSection(title: "Theme") {
                        VStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { theme.isNeon },
                                set: { theme.setNeon($0) }
                            )) {
                                HStack {
                                    Image(systemName: theme.isNeon ? "bolt.fill" : "sparkles")
                                    Text(theme.isNeon ? "Neon Mode" : "Luxury Mode")
                                }
                            }
                            .tint(.purple)
                            
                            Text("Enable vibrant neon glows and effects throughout the app")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    SettingsSection(title: "Color Scheme") {
                        VStack(spacing: 12) {
                            let schemes = ["Purple & Blue", "Teal & Orange", "Lime & Magenta"]
                            ForEach(schemes, id: \.self) { scheme in
                                ColorSchemeOption(title: scheme, isSelected: selectedScheme == scheme) {
                                    selectedScheme = scheme
                                }
                            }
                        }
                    }
                    
                    SettingsSection(title: "Visual Effects") {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Glow Intensity")
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(String(format: "%.0f%%", glowIntensity * 100))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                
                                Slider(value: $glowIntensity, in: 0...1)
                                    .tint(.purple)
                                    .onChange(of: glowIntensity) { newValue in
                                        storedGlowIntensity = newValue
                                    }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorSchemeOption: View {
    let title: String
    let isSelected: Bool
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack {
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.purple)
                }
            }
            .padding()
            .background(Color.white.opacity(isSelected ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @State private var pushEnabled = true
    @State private var likesEnabled = true
    @State private var commentsEnabled = true
    @State private var followsEnabled = true
    @State private var messagesEnabled = true
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Push Notifications") {
                        VStack(spacing: 12) {
                            Toggle("Enable Push Notifications", isOn: $pushEnabled)
                                .tint(.purple)
                            
                            if pushEnabled {
                                Divider()
                                Toggle("Likes", isOn: $likesEnabled).tint(.purple)
                                Toggle("Comments", isOn: $commentsEnabled).tint(.purple)
                                Toggle("New Followers", isOn: $followsEnabled).tint(.purple)
                                Toggle("Messages", isOn: $messagesEnabled).tint(.purple)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    SettingsSection(title: "In-App Notifications") {
                        VStack(spacing: 12) {
                            Toggle("Sound Effects", isOn: .constant(true))
                                .tint(.purple)
                            Toggle("Haptic Feedback", isOn: .constant(true))
                                .tint(.purple)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    @AppStorage("vb.privateAccount") private var privateAccount = false
    @AppStorage("vb.showActivity") private var showActivity = true
    @AppStorage("vb.allowComments") private var allowComments = true
    @AppStorage("vb.allowDuets") private var allowDuets = true

    @State private var showPrivateConfirm = false
    @State private var pendingPrivateValue: Bool? = nil
    @State private var showBlockedList = false

    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Account Privacy") {
                        VStack(spacing: 12) {
                            Toggle("Private Account", isOn: Binding(
                                get: { privateAccount },
                                set: { newValue in
                                    if newValue == true && privateAccount == false {
                                        pendingPrivateValue = newValue
                                        showPrivateConfirm = true
                                    } else {
                                        privateAccount = newValue
                                    }
                                }
                            ))
                            .tint(.purple)
                            .onChange(of: privateAccount) { newValue in
                                postPrivacySync()
                            }
                            
                            Text("Only approved followers can see your posts")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Existing followers will remain; new follows require approval.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    SettingsSection(title: "Activity Status") {
                        Toggle("Show Activity Status", isOn: $showActivity)
                            .tint(.purple)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .onChange(of: showActivity) { _ in postPrivacySync() }
                    }
                    
                    SettingsSection(title: "Interactions") {
                        VStack(spacing: 12) {
                            Toggle("Allow Comments", isOn: $allowComments)
                                .tint(.purple)
                                .onChange(of: allowComments) { _ in postPrivacySync() }
                            Toggle("Allow Duets & Remixes", isOn: $allowDuets)
                                .tint(.purple)
                                .onChange(of: allowDuets) { _ in postPrivacySync() }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    SettingsSection(title: "Content Controls") {
                        NavigationLink {
                            MutedWordsView()
                        } label: {
                            SettingsRow(
                                icon: "speaker.slash.fill",
                                title: "Muted Words",
                                subtitle: "Hide content containing specific words",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 8) {
                            Toggle("Restricted Mode", isOn: .constant(false))
                                .tint(.purple)
                            Text("Limit potentially mature content. This may hide some videos and comments.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    SettingsSection(title: "Blocked Accounts") {
                        NavigationLink {
                            BlockedAccountsView()
                        } label: {
                            SettingsRow(
                                icon: "hand.raised.fill",
                                title: "Blocked Accounts",
                                subtitle: "Manage blocked users",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Privacy & Safety")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Switch to Private Account?", isPresented: $showPrivateConfirm) {
            Button("Cancel", role: .cancel) { pendingPrivateValue = nil }
            Button("Confirm") { privateAccount = true; pendingPrivateValue = nil }
        } message: {
            Text("Only approved followers will be able to see your posts and activity.")
        }
    }
    
    private func postPrivacySync() {
        let payload: [String: Any] = [
            "userId": authManager.currentUserId ?? "",
            "privateAccount": privateAccount,
            "showActivity": showActivity,
            "allowComments": allowComments,
            "allowDuets": allowDuets
        ]
        NotificationCenter.default.post(name: .privacySettingsDidChange, object: nil, userInfo: payload)
        // TODO: Integrate with SupabaseService to persist these settings server-side.
    }
}

struct BlockedAccountsView: View {
    @State private var blockedUsers: [String] = [
        // Placeholder sample data. Replace with real user handles.
    ]

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                Group {
                    if blockedUsers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.raised")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.6))
                            Text("No blocked accounts")
                                .foregroundStyle(.white)
                            Text("You haven't blocked anyone yet.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(blockedUsers, id: \.self) { user in
                                NavigationLink {
                                    BlockedAccountDetailsView(username: user)
                                } label: {
                                    HStack {
                                        Image(systemName: "person.fill.xmark")
                                            .foregroundStyle(.white)
                                        Text(user)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            )
            .navigationTitle("Blocked Accounts")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlockedAccountDetailsView: View {
    let username: String
    @State private var showConfirm = false

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 16) {
                    // Mock profile header
                    HStack(spacing: 12) {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 64, height: 64)
                        VStack(alignment: .leading) {
                            Text(username).font(.headline).foregroundStyle(.white)
                            Text("Blocked user").font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actions").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        Button {
                            showConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Unblock @\(username)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding()
            )
            .navigationTitle("Blocked User")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Unblock @\(username)?", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Unblock", role: .destructive) {
                    // TODO: Perform unblock action and pop.
                }
            } message: {
                Text("They will be able to view your profile and interact with you again.")
            }
    }
}

struct MutedWordsView: View {
    @AppStorage("vb.mutedWords") private var mutedWordsStorage: String = ""
    @State private var newWord: String = ""

    private var words: [String] {
        mutedWordsStorage.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 16) {
                    SettingsSection(title: "Muted Words") {
                        HStack(spacing: 8) {
                            TextField("Add a word or phrase", text: $newWord)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Button {
                                let word = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !word.isEmpty else { return }
                                var set = Set(words)
                                set.insert(word)
                                mutedWordsStorage = set.joined(separator: ",")
                                newWord = ""
                            } label: {
                                Image(systemName: "plus.circle.fill").font(.title3)
                            }
                            .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if words.isEmpty {
                            Text("No muted words yet.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            FlowLayout(tags: words) { word in
                                HStack(spacing: 6) {
                                    Text(word).foregroundStyle(.white)
                                    Button(action: { remove(word) }) {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
            )
            .navigationTitle("Muted Words")
            .navigationBarTitleDisplayMode(.inline)
    }

    private func remove(_ word: String) {
        var set = Set(words)
        set.remove(word)
        mutedWordsStorage = set.joined(separator: ",")
    }
}

// Simple flow layout for tags
struct FlowLayout<TagContent: View>: View {
    let tags: [String]
    let content: (String) -> TagContent

    init(tags: [String], @ViewBuilder content: @escaping (String) -> TagContent) {
        self.tags = tags
        self.content = content
    }

    var body: some View {
        var totalWidth: CGFloat = 0
        var rows: [[String]] = [[]]
        let screenWidth = UIScreen.main.bounds.width - 32
        for tag in tags {
            let tagWidth = CGFloat(tag.count * 8 + 40)
            if totalWidth + tagWidth > screenWidth {
                rows.append([tag])
                totalWidth = tagWidth
            } else {
                rows[rows.count - 1].append(tag)
                totalWidth += tagWidth
            }
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex], id: \.self) { tag in
                        content(tag)
                    }
                }
            }
        }
    }
}

// MARK: - Accessibility Settings

struct AccessibilitySettingsView: View {
    @State private var largeText = false
    @State private var reduceMotion = false
    @State private var autoplayVideos = true
    @State private var captionsEnabled = false
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Display") {
                        VStack(spacing: 12) {
                            Toggle("Large Text", isOn: $largeText).tint(.purple)
                            Toggle("Reduce Motion", isOn: $reduceMotion).tint(.purple)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    SettingsSection(title: "Video Playback") {
                        VStack(spacing: 12) {
                            Toggle("Autoplay Videos", isOn: $autoplayVideos).tint(.purple)
                            Toggle("Always Show Captions", isOn: $captionsEnabled).tint(.purple)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data & Storage Settings

struct DataStorageSettingsView: View {
    @State private var cacheSize = "245 MB"
    @State private var showClearCacheAlert = false
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Storage") {
                        SettingsRow(
                            icon: "internaldrive",
                            title: "Cache Size",
                            subtitle: cacheSize
                        )
                        
                        Button {
                            showClearCacheAlert = true
                        } label: {
                            SettingsRow(
                                icon: "trash",
                                title: "Clear Cache",
                                subtitle: "Free up storage space"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    SettingsSection(title: "Data Usage") {
                        VStack(spacing: 12) {
                            Toggle("Download over Wi-Fi only", isOn: .constant(false))
                                .tint(.purple)
                            Toggle("HD on Mobile Data", isOn: .constant(false))
                                .tint(.purple)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear") {
                // TODO: Implement cache clearing
                cacheSize = "0 MB"
            }
        } message: {
            Text("This will clear all cached images and videos. This action cannot be undone.")
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // App Icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient.primaryNeon)
                            .frame(width: 100, height: 100)
                            .neonGlow()
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 20)
                    
                    Text("VibeX")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Next-Gen Social — Create the Vibe")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 20)
                    
                    SettingsSection(title: "App Information") {
                        SettingsRow(icon: "number", title: "Version", subtitle: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        SettingsRow(icon: "hammer", title: "Build", subtitle: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        SettingsRow(icon: "calendar", title: "Release Date", subtitle: "January 2026")
                    }
                    
                    SettingsSection(title: "Legal") {
                        Button {
                            // TODO: Show terms
                        } label: {
                            SettingsRow(
                                icon: "doc.text",
                                title: "Terms of Service",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            // TODO: Show privacy policy
                        } label: {
                            SettingsRow(
                                icon: "hand.raised",
                                title: "Privacy Policy",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            // TODO: Show licenses
                        } label: {
                            SettingsRow(
                                icon: "doc.badge.gearshape",
                                title: "Open Source Licenses",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Support Mail Helper
struct SupportMailHelper: UIViewControllerRepresentable {
    typealias UIViewControllerType = MFMailComposeViewController

    let recipients: [String]
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - WebView (optional)
struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) { webView.load(URLRequest(url: url)) }
}

// MARK: - Bug Report
struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var descriptionText: String = ""
    @State private var includeDiagnostics: Bool = true
    @State private var showMail = false

    private var supportEmail: String { "kendallprnhub@gmail.com" }

    private var diagnostics: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let system = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        let model = UIDevice.current.model
        return "App: VibeX v\(appVersion) (\(build))\nDevice: \(model)\nOS: \(system)\nUsed AI for help & support: Yes"
    }

    private var mailBody: String {
        var body = "Bug description:\n\n\(descriptionText)\n\n"
        if includeDiagnostics {
            body += "Diagnostics:\n\(diagnostics)\n"
        }
        return body
    }

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 16) {
                    SettingsSection(title: "Report a Bug") {
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 160)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)

                        Toggle("Include diagnostics", isOn: $includeDiagnostics)
                            .tint(.purple)

                        Button {
                            if MFMailComposeViewController.canSendMail() {
                                showMail = true
                            } else {
                                // Fallback to mailto:
                                let subject = "VibeX Bug Report"
                                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
                                let encodedBody = mailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mailBody
                                if let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        } label: {
                            HStack { Image(systemName: "paperplane.fill"); Text("Send Report") }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Spacer()
                }
                .padding()
            )
            .sheet(isPresented: $showMail) {
                SupportMailHelper(
                    recipients: [supportEmail],
                    subject: "VibeX Bug Report",
                    body: mailBody
                )
            }
            .navigationTitle("Report a Bug")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - VibeX Assistant (Gated)
struct VibeXAssistantView: View {
    @AppStorage("vb.aiEnabled") private var aiEnabled: Bool = false
    @State private var showContactMail = false

    private var supportEmail: String { "kendallprnhub@gmail.com" }

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("VibeX AI is coming soon")
                                .font(.title3).bold()
                                .foregroundStyle(.white)
                            Text("We’re building an assistant to help you get answers faster — with privacy-first design.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // What you'll get
                        SettingsSection(title: "What you'll get") {
                            VStack(alignment: .leading, spacing: 10) {
                                featureRow(icon: "sparkles", title: "Instant answers", detail: "Ask how to use features, fix issues, and discover tips.")
                                featureRow(icon: "shield.lefthalf.filled", title: "Privacy-first", detail: "Designed to keep your data safe and local-first where possible.")
                                featureRow(icon: "bolt.horizontal.fill", title: "Smart help", detail: "Troubleshoot and summarize steps automatically.")
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // How it works
                        SettingsSection(title: "How it works") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Ask questions about VibeX features and settings.")
                                Text("• Get step‑by‑step guidance and quick tips.")
                                Text("• Optionally share diagnostics when you contact support.")
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // CTA
                        VStack(spacing: 10) {
                            Button {
                                if MFMailComposeViewController.canSendMail() {
                                    showContactMail = true
                                } else {
                                    let subject = "VibeX AI Early Access"
                                    let body = "Hello, I'd like early access to VibeX AI.\n\nUsed AI for help & support: Yes"
                                    let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
                                    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
                                    if let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            } label: {
                                HStack { Image(systemName: "envelope.fill"); Text("Request Early Access") }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Text("We’ll notify you when VibeX AI is ready.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding()
                }
            )
            .sheet(isPresented: $showContactMail) {
                SupportMailHelper(
                    recipients: [supportEmail],
                    subject: "VibeX AI Early Access",
                    body: "Hello, I'd like early access to VibeX AI.\n\nUsed AI for help & support: Yes"
                )
            }
            .navigationTitle("VibeX Assistant")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }
}

// MARK: - Help & Support

struct HelpSupportView: View {
    @State private var showFAQ = false
    @State private var faqURLString: String = "https://example.com/faq" // Replace with real FAQ URL if available
    @State private var showContactMail = false

    private var supportEmail: String { "kendallprnhub@gmail.com" }

    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Get Help") {
                        Button {
                            showFAQ = true
                        } label: {
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "FAQ",
                                subtitle: "Frequently asked questions",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            if MFMailComposeViewController.canSendMail() {
                                showContactMail = true
                            } else {
                                // Fallback to mailto
                                let subject = "VibeX Support"
                                let body = "Hello Support,\n\n(Write your message here)\n\nUsed AI for help & support: Yes"
                                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
                                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
                                if let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        } label: {
                            SettingsRow(
                                icon: "envelope",
                                title: "Contact Support",
                                subtitle: "Get help from our team",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            BugReportView()
                        } label: {
                            SettingsRow(
                                icon: "ladybug",
                                title: "Report a Bug",
                                subtitle: "Help us improve VibeX",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink {
                            VibeXAssistantView()
                        } label: {
                            SettingsRow(
                                icon: "sparkles",
                                title: "Ask VibeX AI",
                                subtitle: "Get quick answers (coming soon)",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Community") {
                        Button {
                            // TODO: Open community guidelines
                        } label: {
                            SettingsRow(
                                icon: "heart.text.square",
                                title: "Community Guidelines",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            // TODO: Open feedback
                        } label: {
                            SettingsRow(
                                icon: "star",
                                title: "Send Feedback",
                                subtitle: "Share your thoughts",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showFAQ) {
            if let url = URL(string: faqURLString) {
                SafariView(url: url)
            } else {
                Text("Invalid FAQ URL").padding()
            }
        }
        .sheet(isPresented: $showContactMail) {
            SupportMailHelper(
                recipients: [supportEmail],
                subject: "VibeX Support",
                body: "Hello Support,\n\n(Write your message here)\n\nUsed AI for help & support: Yes"
            )
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings Section Container

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 4)
            
            content
        }
    }
}

// MARK: - Admin Tools

struct AdminToolsView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack { Color.vbBackground.ignoresSafeArea() }
            .overlay(
                ScrollView {
                    VStack(spacing: 16) {
                        SettingsSection(title: "Admin Tools") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Signed in as: \(authManager.session?.user.email ?? "Unknown email")")
                                    .foregroundStyle(.white)
                                Text("User ID: \(authManager.currentUserId.map { $0.uuidString } ?? "Unknown ID")")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Owner Access Enabled")
                                    .foregroundStyle(.white)
                                Text("This panel is visible only to the owner account.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
            )
            .navigationTitle("Admin Tools")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}

