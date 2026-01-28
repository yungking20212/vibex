//
//  SupabaseConfig.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import Foundation
import Supabase

// MARK: - Supabase Client Configuration

final class SupabaseConfig: Sendable {
    static let shared = SupabaseConfig()
    
    let client: SupabaseClient
    // Expose raw URL and anon key for parts of the app that need REST endpoints
    let supabaseURL: URL
    let supabaseKey: String
    
    // Storage bucket name
    static let bucketVideos = "videos"
    
    private init() {
        // Your Supabase credentials
        let _supabaseURL = URL(string: "https://jnkzbfqrwkgfiyxvwrug.supabase.co")!
        let _supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impua3piZnFyd2tnZml5eHZ3cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NDQ0NDgsImV4cCI6MjA4NDAyMDQ0OH0.20qAetWuXPOeA_fcflj_wdx_-mwKlHIszVvgEwa8sZo"

        self.supabaseURL = _supabaseURL
        self.supabaseKey = _supabaseKey

        self.client = SupabaseClient(
            supabaseURL: _supabaseURL,
            supabaseKey: _supabaseKey
        )
    }
}
