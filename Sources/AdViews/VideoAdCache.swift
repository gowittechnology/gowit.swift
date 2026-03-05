import Foundation

// MARK: - Video Ad Cache

/// Disk-based LRU cache for downloaded video ad files.
///
/// Files are stored in `Library/Caches/GowitVideoCache/` and keyed by a
/// deterministic hash of the original video URL, so the same ad URL always
/// resolves to the same file without a network round-trip.
///
/// **Eviction** runs automatically on every write:
/// - Files older than `maxCacheAge` are deleted first.
/// - If the total size still exceeds `maxCacheSizeBytes`, the least-recently-used
///   files are deleted until the cache is back at 75 % of the limit.
///
/// The OS may also purge `Library/Caches` independently under low-storage
/// conditions; the SDK handles that gracefully by treating a missing file as a
/// cache miss and re-downloading.
actor VideoAdCache {

    // MARK: - Shared Instance

    static let shared = VideoAdCache()

    // MARK: - Limits (adjust once, applies to all VideoAdView instances)

    /// Maximum combined on-disk size for all cached video files. Default: 200 MB.
    let maxCacheSizeBytes: Int = 200 * 1024 * 1024

    /// Files not accessed within this interval are considered stale. Default: 7 days.
    let maxCacheAge: TimeInterval = 7 * 24 * 3600

    // MARK: - Private

    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("GowitVideoCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Returns the cached file URL for `sourceURL` when a valid on-disk entry exists.
    ///
    /// Accessing a cached file updates its modification date so the LRU eviction
    /// policy correctly identifies least-recently-used entries.
    func cachedFileURL(for sourceURL: URL) -> URL? {
        let path = cacheFilePath(for: sourceURL)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        // Touch modification date → LRU access tracking
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: path.path)
        return path
    }

    /// Moves `localFile` into the cache directory, keyed by `sourceURL`.
    ///
    /// Returns the permanent cache URL on success, or `localFile` unchanged if
    /// the move fails (e.g. unexpected cross-volume condition).
    /// Eviction is triggered synchronously within the actor after the write.
    @discardableResult
    func store(localFile: URL, for sourceURL: URL) -> URL {
        let destination = cacheFilePath(for: sourceURL)
        try? fileManager.removeItem(at: destination)
        do {
            try fileManager.moveItem(at: localFile, to: destination)
            evict()
            return destination
        } catch {
            // Move failed: caller plays from the original temp location
            return localFile
        }
    }

    /// Removes every file from the cache directory.
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func cacheFilePath(for url: URL) -> URL {
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        return cacheDirectory.appendingPathComponent("\(cacheKey(for: url)).\(ext)")
    }

    /// Deterministic 16-character hex key derived from the URL string.
    ///
    /// Uses a DJB2-variant hash. Cryptographic strength is not required here;
    /// the hash only needs to be stable and collision-resistant enough for a
    /// local file cache.
    private func cacheKey(for url: URL) -> String {
        var hash: UInt64 = 5381
        for byte in url.absoluteString.utf8 {
            hash = (hash &<< 5) &+ hash &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }

    // MARK: - Eviction

    private struct CacheEntry {
        let url: URL
        let modified: Date
        let size: Int
    }

    /// Removes stale files, then trims to `maxCacheSizeBytes` by deleting
    /// the least-recently-used (oldest modification date) entries first.
    private func evict() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        let now = Date()
        var survivors: [CacheEntry] = []

        // Pass 1 — remove expired entries
        for file in files {
            let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modified = attrs?.contentModificationDate ?? .distantPast
            let size = attrs?.fileSize ?? 0
            if now.timeIntervalSince(modified) > maxCacheAge {
                try? fileManager.removeItem(at: file)
            } else {
                survivors.append(CacheEntry(url: file, modified: modified, size: size))
            }
        }

        // Pass 2 — LRU trim if still over the size limit
        let totalBytes = survivors.reduce(0) { $0 + $1.size }
        guard totalBytes > maxCacheSizeBytes else { return }

        // Trim down to 75 % of the limit so the next few writes don't immediately re-trigger eviction
        let target = (maxCacheSizeBytes / 4) * 3
        var freed = 0
        for entry in survivors.sorted(by: { $0.modified < $1.modified }) {
            guard totalBytes - freed > target else { break }
            try? fileManager.removeItem(at: entry.url)
            freed += entry.size
        }
    }
}
