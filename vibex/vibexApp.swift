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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                // RootView sits at the base of the navigation stack
                ZStack {
                    RootView()
                        .environmentObject(authManager)
                        .environmentObject(supabaseService)
                        .environmentObject(draftStore)
                        .onOpenURL { url in
                            deepLinkRouter.handle(url: url)
                        }
                }

                // Hidden NavigationLink activated when a deep link arrives
                NavigationLink(isActive: $deepLinkRouter.showProfile) {
                    Group {
                        if let target = deepLinkRouter.profileTarget {
                            switch target {
                            case .userID(let id):
                                ProfileView(userID: id)
                            case .username(let name):
                                ProfileView(username: name)
                            }
                        } else {
                            EmptyView()
                        }
                    }
                } label: {
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    // Resume or refresh tasks as needed
                    break
                case .inactive:
                    // Pause ongoing work, save state if necessary
                    break
                case .background:
                    // Perform background cleanup or schedule tasks
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

