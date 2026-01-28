import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import Combine

enum FXPreset: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case cinematicGlow = "Cinematic Glow"
    case neon = "Neon"
    case vhs = "VHS"
    case comic = "Comic"
    case funnyWarp = "Funny Warp"

    var id: String { rawValue }
}

@MainActor
final class VideoFXEngine: ObservableObject {
    @Published var isExporting = false
    @Published var progress: Double = 0
    @Published var errorText: String?

    private let ciContext = CIContext(options: nil)

    func exportWithPreset(inputURL: URL, preset: FXPreset, overlayText: String?) async -> URL? {
        errorText = nil
        isExporting = true
        progress = 0
        defer { isExporting = false }

        let asset = AVURLAsset(url: inputURL)

        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            errorText = "No video track found."
            return nil
        }

        do {
            let composition = AVMutableComposition()
            let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))

            try compVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)

            // Keep audio if available
            if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try? compAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)

            // Build a filter video composition
            let videoComposition = AVMutableVideoComposition(asset: composition) { request in
                var image = request.sourceImage.clampedToExtent()

                // Apply preset filters
                image = Self.applyPreset(preset, to: image)

                // Optional text overlay (simple)
                if let text = overlayText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    image = Self.drawText(text, on: image)
                }

                image = image.cropped(to: request.sourceImage.extent)
                request.finish(with: image, context: nil)
            }

            // Fix orientation
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRange

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack!)
            layerInstruction.setTransform(preferredTransform, at: .zero)
            instruction.layerInstructions = [layerInstruction]

            videoComposition.instructions = [instruction]
            videoComposition.renderSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

            let outURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("vibex_fx_\(UUID().uuidString).mp4")

            if FileManager.default.fileExists(atPath: outURL.path) {
                try? FileManager.default.removeItem(at: outURL)
            }

            guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                errorText = "Could not create export session."
                return nil
            }

            export.outputURL = outURL
            export.outputFileType = .mp4
            export.videoComposition = videoComposition
            export.shouldOptimizeForNetworkUse = true

            // Progress polling (async) — use a cancellable Task loop instead of Timer
            let pollingTask = Task { [weak export] in
                while let export = export, export.error == nil && export.progress < 1.0 {
                    await MainActor.run {
                        self.progress = Double(export.progress)
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    if Task.isCancelled {
                        export.cancelExport()
                        break
                    }
                }
                if let export = export {
                    await MainActor.run { self.progress = Double(export.progress) }
                }
            }

            // Use the non-deprecated async wrapper for the older async APIs by converting the
            // callback-based `exportAsynchronously` into an async continuation. This avoids
            // calling the newer `export()` that is deprecated on some SDKs.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                export.exportAsynchronously {
                    if let err = export.error {
                        continuation.resume(throwing: err)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }

            pollingTask.cancel()

            if export.status == .completed {
                self.progress = 1
                return outURL
            } else {
                self.errorText = export.error?.localizedDescription ?? "Export failed."
                return nil
            }

        } catch {
            self.errorText = error.localizedDescription
            return nil
        }
    }

    // MARK: - Filters

    nonisolated private static func applyPreset(_ preset: FXPreset, to image: CIImage) -> CIImage {
        switch preset {
        case .clean:
            return image

        case .cinematicGlow:
            let bloom = CIFilter.bloom()
            bloom.inputImage = image
            bloom.intensity = 0.5
            bloom.radius = 12.0
            return bloom.outputImage ?? image

        case .neon:
            let edges = CIFilter.edges()
            edges.inputImage = image
            edges.intensity = 8
            let edgeImg = (edges.outputImage ?? image)
                .applyingFilter("CIColorInvert")
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.6,
                    kCIInputContrastKey: 1.25,
                    kCIInputBrightnessKey: 0.05
                ])
            return edgeImg.composited(over: image)

        case .vhs:
            let color = image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.15,
                kCIInputContrastKey: 1.1,
                kCIInputBrightnessKey: -0.02
            ])
            let noise = CIFilter.randomGenerator().outputImage?
                .cropped(to: image.extent)
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0.10),
                    "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0.10),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0.10),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.12)
                ])
            if let noise { return noise.composited(over: color) }
            return color

        case .comic:
            return image.applyingFilter("CIComicEffect")

        case .funnyWarp:
            let bump = CIFilter.bumpDistortion()
            bump.inputImage = image
            bump.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
            bump.radius = Float(min(image.extent.width, image.extent.height) * 0.35)
            bump.scale = 0.4
            return bump.outputImage ?? image
        }
    }

    // Simple text overlay (CI)
    nonisolated private static func drawText(_ text: String, on image: CIImage) -> CIImage {
        // Minimal v1: just darken bottom and “pretend” overlay (keeps compile stable)
        // Real text drawing with CoreGraphics + CIImage can be added next.
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: image.extent.midX, y: image.extent.minY)
        gradient.point1 = CGPoint(x: image.extent.midX, y: image.extent.minY + 320)
        gradient.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.70)
        gradient.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.0)
        let g = (gradient.outputImage ?? CIImage()).cropped(to: image.extent)

        // We’ll return image with readability fade; UI text sits on top in SwiftUI.
        return g.composited(over: image)
    }
}
