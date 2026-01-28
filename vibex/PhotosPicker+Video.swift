import Foundation
import _PhotosUI_SwiftUI
import PhotosUI

enum VideoPickError: Error {
    case couldNotLoad
    case couldNotWrite
}

extension PhotosPickerItem {
    func loadVideoFileURL() async throws -> URL {
        // Try URL first (best)
        if let url = try? await self.loadTransferable(type: URL.self) {
            return url
        }

        // Fallback: Data -> temp file
        if let data = try? await self.loadTransferable(type: Data.self) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            do {
                try data.write(to: tmp, options: .atomic)
                return tmp
            } catch {
                throw VideoPickError.couldNotWrite
            }
        }

        throw VideoPickError.couldNotLoad
    }
}
