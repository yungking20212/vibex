//
//  SettingsView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/25/26.
//

import SwiftUI
import { createClient } from '@supabase/supabase-js'
import Supabase

const SUPABASE_URL = process.env.SUPABASE_URL!
const SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY! // secret you set
const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
})

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSection: SettingsSection? = nil
    @State private var showSignOutConfirmation = false
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case account = "Account"
        case appearance = "Appearance"
        case notifications = "Notifications"
        case privacy = "Privacy & Safety"
        case accessibility = "Accessibility"
        case dataStorage = "Data & Storage"
        case about = "About"
        case help = "Help & Support"
        
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
                            ForEach(SettingsSection.allCases) { section in
                                NavigationLink {
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
        case .accessibility:
            AccessibilitySettingsView()
        case .dataStorage:
            DataStorageSettingsView()
        case .about:
            AboutSettingsView()
        case .help:
            HelpSupportView()
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
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Profile Information") {
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
                    }
                    
                    SettingsSection(title: "Account Actions") {
                        Button {
                            // TODO: Implement password change
                        } label: {
                            SettingsRow(
                                icon: "key.fill",
                                title: "Change Password",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            // TODO: Implement email change
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
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var glowIntensity: Double = 1.0
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
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
                            ColorSchemeOption(title: "Purple & Blue", isSelected: true)
                            ColorSchemeOption(title: "Teal & Orange", isSelected: false)
                            ColorSchemeOption(title: "Lime & Magenta", isSelected: false)
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
    
    var body: some View {
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
    @State private var privateAccount = false
    @State private var showActivity = true
    @State private var allowComments = true
    @State private var allowDuets = true
    
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Account Privacy") {
                        VStack(spacing: 12) {
                            Toggle("Private Account", isOn: $privateAccount)
                                .tint(.purple)
                            
                            Text("Only approved followers can see your posts")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
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
                    }
                    
                    SettingsSection(title: "Interactions") {
                        VStack(spacing: 12) {
                            Toggle("Allow Comments", isOn: $allowComments).tint(.purple)
                            Toggle("Allow Duets & Remixes", isOn: $allowDuets).tint(.purple)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    SettingsSection(title: "Blocked Accounts") {
                        Button {
                            // TODO: Show blocked accounts list
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

// MARK: - Help & Support

struct HelpSupportView: View {
    var body: some View {
        ZStack {
            Color.vbBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Get Help") {
                        Button {
                            // TODO: Open FAQ
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
                            // TODO: Contact support
                        } label: {
                            SettingsRow(
                                icon: "envelope",
                                title: "Contact Support",
                                subtitle: "Get help from our team",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            // TODO: Report bug
                        } label: {
                            SettingsRow(
                                icon: "ladybug",
                                title: "Report a Bug",
                                subtitle: "Help us improve VibeX",
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

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        Label("AI Settings", systemImage: "brain.head.profile")
                    }

                    NavigationLink {
                        AboutVibexView()
                    } label: {
                        Label("About Vibex", systemImage: "sparkles")
                    }
                }

                // other settings sections...
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

// NOTE: presign_upload Edge Function examples removed — the app now uses direct
// client-side Storage uploads via the Supabase client. See `SupabaseVideoUploader`
// for the upload implementation.