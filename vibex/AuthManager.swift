//
//  AuthManager.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var session: Session?
    @Published var isLoading: Bool = true
    @Published var hasBootstrapped: Bool = false
    @Published var authError: String?
    @Published var profile: Profile?

    private let client = SupabaseConfig.shared.client

    // `Profile` is now a top-level model in `Models.swift` to avoid
    // MainActor isolation when used with Supabase generics.



    private init() {
        // Observe token refresh events from upload helper and attempt to reload SDK session.
        NotificationCenter.default.addObserver(self, selector: #selector(handleSupabaseTokenRefreshed), name: Notification.Name("supabaseTokenRefreshed"), object: nil)
    }

    @objc private func handleSupabaseTokenRefreshed() {
        Task { @MainActor in
            do {
                // Ask the SDK for its current session; if the SDK picked up a stored session, update our published `session`.
                let s = try await client.auth.session
                self.session = s
            } catch {
                // Best-effort: if SDK session cannot be read, clear and let the app re-bootstrap when needed.
                self.session = nil
            }
        }
    }

    // MARK: - Boot / Restore Session
    func start() async {
        isLoading = true
        defer {
            isLoading = false
            hasBootstrapped = true
        }

        authError = nil

        do {
            // ✅ In supabase-swift, session access can throw when none exists
            let s = try await client.auth.session
            session = s

            // Bootstrap profile
            try await ensureProfileExists(userId: s.user.id)
            profile = try await fetchProfile(userId: s.user.id)
        } catch {
            session = nil
            profile = nil
        }
    }

    // MARK: - Auth
    func signUp(email: String, password: String, username: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(email: email, password: password)

            // ✅ Get session correctly
            session = response.session

            guard let userId = session?.user.id else {
                authError = "Sign up succeeded, but session is missing. Check email confirmation settings in Supabase Auth."
                return
            }

            try await ensureProfileExists(userId: userId, preferredUsername: username)
            profile = try await fetchProfile(userId: userId)

        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // ✅ signIn returns Session directly
            session = try await client.auth.signIn(email: email, password: password)

            guard let userId = session?.user.id else {
                authError = "Signed in, but session is missing."
                return
            }

            try await ensureProfileExists(userId: userId)
            profile = try await fetchProfile(userId: userId)

        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() async {
        authError = nil
        do {
            try await client.auth.signOut()
            session = nil
            profile = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Profiles
    func fetchProfile(userId: UUID) async throws -> Profile {
        try await client.database
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    /// Creates a profile row if missing (id = auth.uid()).
    func ensureProfileExists(userId: UUID, preferredUsername: String? = nil) async throws {
        let existing: [Profile] = try await client.database
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        if !existing.isEmpty { return }

        let safeUsername = preferredUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let generated = "user\(Int.random(in: 1000...9999))"

        let profile = Profile(
            id: userId,
            username: (safeUsername?.isEmpty == false) ? safeUsername! : generated,
            display_name: (safeUsername?.isEmpty == false) ? safeUsername! : "VibeX User",
            avatar_url: nil,
            created_at: Date(),
            updated_at: Date()
        )

        _ = try await client.database
            .from("profiles")
            .insert(profile)
            .execute()
    }

    // MARK: - Computed
    var isAuthenticated: Bool { session != nil }
    var currentUserId: UUID? { session?.user.id }
}

