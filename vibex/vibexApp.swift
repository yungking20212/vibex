//
//  vibexApp.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI

@main
struct vibexApp: App {
    @State private var authManager = AuthManager.shared
    @State private var supabaseService = SupabaseService.shared
    @StateObject private var draftStore = DraftStore()
    @State private var pendingDeepLinkURL: URL? = nil
    @State private var showDeepLinkProfile: Bool = false
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
                .environmentObject(draftStore)
                .onOpenURL { url in
                    // Lightweight filter for profile deep links
                    let path = url.path.lowercased()
                    if path.hasPrefix("/profile") || url.host?.lowercased() == "profile" {
                        pendingDeepLinkURL = url
                        showDeepLinkProfile = true
                    }
                }
                .sheet(isPresented: $showDeepLinkProfile) {
                    if let url = pendingDeepLinkURL {
                        ProfileDeepLinkRouter(url: url)
                    } else {
                        EmptyView()
                    }
                }
                .task {
                    await authManager.start()
                    // Initialize AI client with developer-provided base URL (no token)
                    // You can change or clear this in Upload Hub → ⚙︎ AI Settings.
                    AINetworkClient.shared.configure(baseURLString: "https://jnkzbfqrwkgfiyxvwrug.supabase.co", bearerToken: nil)
                    // Configure Supabase project and API key for functions access
                    AINetworkClient.shared.configureSupabase(project: "jnkzbfqrwkgfiyxvwrug", apiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impua3piZnFyd2tnZml5eHZ3cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NDQ0NDgsImV4cCI6MjA4NDAyMDQ0OH0.20qAetWuXPOeA_fcflj_wdx_-mwKlHIszVvgEwa8sZo")

                    // Configure URLCache limits and perform cache maintenance
                    CacheCleaner.configureURLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
                    Task.detached {
                        await CacheCleaner.performMaintenanceIfNeeded(maxDiskUsage: 150 * 1024 * 1024)
                    }
                }
        }
    }
}

