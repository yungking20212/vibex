import Foundation
import UIKit

enum CacheCleaner {
    /// Configure a shared URLCache with given memory/disk capacities (bytes).
    static func configureURLCache(memoryCapacity: Int, diskCapacity: Int) {
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "vibex_urlcache")
        URLCache.shared = cache
        print("[CacheCleaner] URLCache configured: mem=\(memoryCapacity) disk=\(diskCapacity)")
    }

    /// Returns the current size (bytes) of files in the Caches directory used by the app.
    static func currentCachesSize() -> Int64 {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return 0 }
        return totalSize(of: caches)
    }

    private static func totalSize(of url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let attrs = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if attrs.isRegularFile == true {
                    total += Int64(attrs.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        return total
    }

    /// Purge URLCache and optionally delete large files under Caches that exceed threshold.
    static func purgeCaches(aggressively: Bool = false, keepBelow bytes: Int64 = 100 * 1024 * 1024) {
        print("[CacheCleaner] Purging URLCache and cleaning caches (aggressive=\(aggressively))")
        URLCache.shared.removeAllCachedResponses()

        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }

        // If aggressive, delete files older than 7 days or until size below target.
        let target = bytes

        var items: [(URL, Int64, Date)] = []
        if let enumerator = fm.enumerator(at: caches, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey], options: [], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                do {
                    let vals = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
                    if vals.isRegularFile == true {
                        let size = Int64(vals.fileSize ?? 0)
                        let mod = vals.contentModificationDate ?? Date.distantPast
                        items.append((fileURL, size, mod))
                    }
                } catch { continue }
            }
        }

        // Sort by oldest first (so we remove old files first)
        items.sort { $0.2 < $1.2 }

        var total = currentCachesSize()
        if total <= target {
            print("[CacheCleaner] Cache size (\(total)) is below target (\(target)). No deletion needed.")
            return
        }

        for (url, size, mod) in items {
            if total <= target { break }
            // Skip very recent files unless aggressive
            if !aggressively && Date().timeIntervalSince(mod) < (24 * 60 * 60) { continue }
            do {
                try fm.removeItem(at: url)
                total -= size
                print("[CacheCleaner] Removed \(url.lastPathComponent) (\(size) bytes). New total=\(total)")
            } catch {
                // ignore deletion errors
            }
        }

        // Final URLCache cleanup
        URLCache.shared.removeAllCachedResponses()
        print("[CacheCleaner] Finished cleaning. Final cache size=\(total)")
    }

    /// If cache usage exceeds maxDiskUsage, run maintenance to shrink.
    static func performMaintenanceIfNeeded(maxDiskUsage: Int64) async {
        let size = currentCachesSize()
        print("[CacheCleaner] Current caches size=\(size) bytes. Threshold=\(maxDiskUsage)")
        if size > maxDiskUsage {
            // First, try a soft URLCache clear
            URLCache.shared.removeAllCachedResponses()
            // Recompute
            let newSize = currentCachesSize()
            if newSize > maxDiskUsage {
                // Aggressive purge
                purgeCaches(aggressively: true, keepBelow: maxDiskUsage)
            }
        }
    }

    /// Helper: list the top-N largest files in Caches (for diagnostics)
    static func largestCacheFiles(limit: Int = 10) -> [(URL, Int64)] {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return [] }
        var items: [(URL, Int64)] = []
        if let enumerator = fm.enumerator(at: caches, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                do {
                    let vals = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if vals.isRegularFile == true {
                        let size = Int64(vals.fileSize ?? 0)
                        items.append((fileURL, size))
                    }
                } catch { continue }
            }
        }
        return items.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }
}
