//
//  EditProfileView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/25/26.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var service: SupabaseService
    
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var bio: String = ""
    
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.vbBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Edit Profile")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                            
                            Text("Update your public information")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Username
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                HStack {
                                    Text("@")
                                        .foregroundStyle(.white.opacity(0.6))
                                    TextField("username", text: $username)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                
                                Text("Your unique handle across VibeX")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            // Display Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                TextField("Your name", text: $displayName)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                
                                Text("This is how you appear to others")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            // Bio
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bio")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                ZStack(alignment: .topLeading) {
                                    if bio.isEmpty {
                                        Text("Tell us about yourself...")
                                            .foregroundStyle(.white.opacity(0.4))
                                            .padding(.top, 12)
                                            .padding(.leading, 16)
                                    }
                                    
                                    TextEditor(text: $bio)
                                        .foregroundColor(.white)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 120)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                
                                HStack {
                                    Text("\(bio.count)/160 characters")
                                        .font(.caption)
                                        .foregroundStyle(bio.count > 160 ? .red : .white.opacity(0.5))
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Save Button
                        Button {
                            Task {
                                await saveProfile()
                            }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save Changes")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.vbPurple, Color.vbPink, Color.vbBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.vbPurple.opacity(0.3), radius: 10)
                        }
                        .disabled(isSaving || bio.count > 160 || username.isEmpty)
                        .opacity(isSaving || bio.count > 160 || username.isEmpty ? 0.6 : 1)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    .padding(.vertical, 20)
                }
                
                // Success Toast
                if showSuccess {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                            Text("Profile updated successfully")
                                .foregroundStyle(.white)
                                .font(.subheadline)
                                .bold()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 22)
                        .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        username = authManager.profile?.username ?? ""
        displayName = authManager.profile?.display_name ?? ""
        bio = authManager.profile?.bio ?? ""
    }
    
    private func saveProfile() async {
        guard let userId = authManager.currentUserId else {
            errorMessage = "User ID not found"
            showError = true
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let updatedProfile = try await service.updateProfile(
                userId: userId,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Update local profile
            authManager.profile = updatedProfile
            
            // Show success toast
            withAnimation(.spring(duration: 0.35)) {
                showSuccess = true
            }
            
            // Trigger success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Post notification to refresh profile
            NotificationCenter.default.post(name: .profileShouldRefresh, object: nil)
            
            // Hide toast and dismiss after delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                showSuccess = false
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            
            // Error haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthManager.shared)
        .environmentObject(SupabaseService.shared)
}
