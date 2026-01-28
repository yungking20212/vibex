import Foundation
import SwiftUI

/// Registers all available Vibex AI models so they are available across the app (all tabs).
/// Call this once at app startup, e.g. in your @main App init.
public func registerDefaultVibexModels() {
    let registry = VibexModelRegistry.shared

    func ensureRegistered(_ model: VibexAIModel) {
        if registry.model(withID: model.id) == nil {
            registry.register(model)
        }
    }

    // Register real models only (no placeholders):
    ensureRegistered(VibeAIGiseModel())

    // If you have additional real models, add them here and ensure they conform to VibexAIModel.
}

// Usage:
// In your @main App init or early lifecycle:
// registerDefaultVibexModels()
