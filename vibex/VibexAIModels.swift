import Foundation
import Combine
import SwiftUI

/// Protocol that describes a Vibex AI model capability surface.
protocol VibexAIModel {
    /// Stable identifier for the model (e.g., "vibe-ai-gise-1.0").
    var id: String { get }
    /// User-facing display name (e.g., "Vibe AI Gise").
    var displayName: String { get }
    /// Declared capabilities supported by this model.
    var capabilities: Set<Capability> { get }

    /// Generate an image for a prompt. Implement using on-device or backend runtime.
    /// - Parameters:
    ///   - prompt: Text prompt to guide generation.
    ///   - seed: Optional seed for reproducibility.
    /// - Returns: A local file URL for the generated image.
    func generateImage(prompt: String, seed: Int?) async throws -> URL
}

/// Capabilities a model can provide.
enum Capability: Hashable {
    case imageGeneration
    case textGeneration
    case upscaling
}

/// Registry for available Vibex AI models, used by AI Hub to list/select models.
final class VibexModelRegistry: ObservableObject {
    
    static let shared = VibexModelRegistry()

    @Published private(set) var models: [VibexAIModel] = []

    init() {}

    /// Register a model instance.
    func register(_ model: VibexAIModel) {
        models.append(model)
    }

    /// Lookup a model by its identifier.
    func model(withID id: String) -> VibexAIModel? {
        models.first { $0.id == id }
    }

    /// Return models supporting a given capability.
    func models(supporting capability: Capability) -> [VibexAIModel] {
        models.filter { $0.capabilities.contains(capability) }
    }
}

/// Concrete implementation for the "Vibe AI Gise" model.
struct VibeAIGiseModel: VibexAIModel {
    let id: String = "vibe-ai-gise-1.0"
    let displayName: String = "Vibe AI Gise"
    let capabilities: Set<Capability> = [.imageGeneration]

    func generateImage(prompt: String, seed: Int?) async throws -> URL {
        // TODO: Implement your on-device or backend call here.
        // Return a file URL to the generated image. For now, throw.
        throw NSError(domain: "VibexAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vibe AI Gise not implemented."])
    }
}

// MARK: - Usage
// Register your models at app startup:
// VibexModelRegistry.shared.register(VibeAIGiseModel())
// Then in AI Hub, list registry.models and allow selection by model.id.

