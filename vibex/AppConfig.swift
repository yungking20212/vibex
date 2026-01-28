import Foundation

enum AppConfig {
    // Reads the Supabase anon key from Info.plist (key: SUPABASE_ANON_KEY)
    // Add a String entry to your target's Info.plist with this key and your anon key value.
    static var supabaseAnonKey: String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !value.isEmpty {
            return value
        }
        return nil
    }
}
