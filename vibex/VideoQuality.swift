import Foundation
import AVFoundation

public enum VideoQuality: String, CaseIterable, Identifiable {
    case p1080 = "1080p"
    case p4k = "4K"

    public var id: String { rawValue }

    public var exportPreset: String {
        switch self {
        case .p1080: return AVAssetExportPreset1920x1080
        case .p4k: return AVAssetExportPreset3840x2160
        }
    }
}
