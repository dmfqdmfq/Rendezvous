import Foundation
import Combine

struct GalleryDownloadItem: Identifiable {
    enum State: Equatable {
        case downloading
        case downloaded
        case failed
    }

    let gallery: GalleryInfo
    var completedPages: Int
    var state: State

    var id: String {
        gallery.id
    }

    var progress: Double {
        guard !gallery.files.isEmpty else {
            return state == .downloaded ? 1 : 0
        }

        return Double(completedPages) / Double(gallery.files.count)
    }
}

@MainActor
final class GalleryLibraryStore: ObservableObject {
    @Published private(set) var favorites: [GalleryInfo] = []
    @Published private(set) var downloads: [GalleryDownloadItem] = []

    private let favoritesURL: URL
    private let downloadsURL: URL
    private let downloadService: GalleryDownloadService
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var downloadIdentifiers: [String: UUID] = [:]

    init(fileManager: FileManager = .default) {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let libraryURL = applicationSupportURL
            .appendingPathComponent("Rendezvous", isDirectory: true)
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let downloadsURL = documentsURL
            .appendingPathComponent("Downloads", isDirectory: true)

        try? fileManager.createDirectory(
            at: libraryURL,
            withIntermediateDirectories: true
        )
        try? fileManager.createDirectory(
            at: downloadsURL,
            withIntermediateDirectories: true
        )

        favoritesURL = libraryURL.appendingPathComponent("favorites.json")
        self.downloadsURL = downloadsURL
        downloadService = GalleryDownloadService(
            downloadsURL: downloadsURL
        )
        favorites = Self.loadFavorites(from: favoritesURL)
        downloads = Self.loadCompletedDownloads(
            from: downloadsURL,
            fileManager: fileManager
        )
    }

    // MARK: - お気に入り

    func isFavorite(_ galleryID: String) -> Bool {
        favorites.contains { $0.id == galleryID }
    }

    func toggleFavorite(_ gallery: GalleryInfo) {
        if let index = favorites.firstIndex(where: { $0.id == gallery.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(gallery, at: 0)
        }

        saveFavorites()
    }

    // MARK: - ダウンロード

    func downloadItem(for galleryID: String) -> GalleryDownloadItem? {
        downloads.first { $0.id == galleryID }
    }

    func downloadedDirectoryURL(for galleryID: String) -> URL? {
        guard downloadItem(for: galleryID)?.state == .downloaded else {
            return nil
        }

        let directoryURL = downloadsURL.appendingPathComponent(
            galleryID,
            isDirectory: true
        )
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: directoryURL.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return nil
        }

        return directoryURL
    }

    func startDownload(_ gallery: GalleryInfo) {
        if let item = downloadItem(for: gallery.id),
           item.state == .downloading || item.state == .downloaded {
            return
        }

        downloadTasks[gallery.id]?.cancel()

        let identifier = UUID()
        downloadIdentifiers[gallery.id] = identifier

        replaceDownloadItem(
            GalleryDownloadItem(
                gallery: gallery,
                completedPages: 0,
                state: .downloading
            )
        )

        downloadTasks[gallery.id] = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await downloadService.download(gallery) { completedPages in
                    await self.updateProgress(
                        galleryID: gallery.id,
                        completedPages: completedPages,
                        identifier: identifier
                    )
                }

                markDownloadCompleted(
                    galleryID: gallery.id,
                    identifier: identifier
                )
            } catch is CancellationError {
                markDownloadFailed(
                    galleryID: gallery.id,
                    identifier: identifier
                )
            } catch {
#if DEBUG
                print("[Download][\(gallery.id)] ERROR:", error)
#endif
                markDownloadFailed(
                    galleryID: gallery.id,
                    identifier: identifier
                )
            }

            if downloadIdentifiers[gallery.id] == identifier {
                downloadTasks[gallery.id] = nil
                downloadIdentifiers[gallery.id] = nil
            }
        }
    }

    func cancelDownload(_ galleryID: String) {
        downloadTasks[galleryID]?.cancel()
    }

    func deleteDownload(_ galleryID: String) async {
        downloadTasks[galleryID]?.cancel()
        downloadTasks[galleryID] = nil
        downloadIdentifiers[galleryID] = nil

        do {
            try await downloadService.delete(galleryID: galleryID)
            downloads.removeAll { $0.id == galleryID }
        } catch {
#if DEBUG
            print("[Download][\(galleryID)] DELETE ERROR:", error)
#endif

            if let index = downloads.firstIndex(where: { $0.id == galleryID }) {
                var item = downloads[index]
                item.state = .failed
                downloads[index] = item
            }
        }
    }

    private func updateProgress(
        galleryID: String,
        completedPages: Int,
        identifier: UUID
    ) {
        guard downloadIdentifiers[galleryID] == identifier,
              let index = downloads.firstIndex(where: { $0.id == galleryID }) else {
            return
        }

        var item = downloads[index]
        item.completedPages = completedPages
        item.state = .downloading
        downloads[index] = item
    }

    private func markDownloadCompleted(
        galleryID: String,
        identifier: UUID
    ) {
        guard downloadIdentifiers[galleryID] == identifier,
              let index = downloads.firstIndex(where: { $0.id == galleryID }) else {
            return
        }

        var item = downloads[index]
        item.completedPages = item.gallery.files.count
        item.state = .downloaded
        downloads[index] = item
    }

    private func markDownloadFailed(
        galleryID: String,
        identifier: UUID
    ) {
        guard downloadIdentifiers[galleryID] == identifier,
              let index = downloads.firstIndex(where: { $0.id == galleryID }),
              downloads[index].state != .downloaded else {
            return
        }

        var item = downloads[index]
        item.state = .failed
        downloads[index] = item
    }

    private func replaceDownloadItem(_ item: GalleryDownloadItem) {
        if let index = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[index] = item
        } else {
            downloads.insert(item, at: 0)
        }
    }

    // MARK: - 永続化

    private func saveFavorites() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(favorites)
            try data.write(to: favoritesURL, options: .atomic)
        } catch {
#if DEBUG
            print("[Favorites] SAVE ERROR:", error)
#endif
        }
    }

    private static func loadFavorites(from url: URL) -> [GalleryInfo] {
        guard let data = try? Data(contentsOf: url),
              let galleries = try? JSONDecoder().decode(
                [GalleryInfo].self,
                from: data
              ) else {
            return []
        }

        return galleries
    }

    private static func loadCompletedDownloads(
        from downloadsURL: URL,
        fileManager: FileManager
    ) -> [GalleryDownloadItem] {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return directories.compactMap { directoryURL in
            let metadataURL = directoryURL.appendingPathComponent("gallery.json")

            guard let data = try? Data(contentsOf: metadataURL),
                  let gallery = try? JSONDecoder().decode(
                    GalleryInfo.self,
                    from: data
                  ) else {
                return nil
            }

            return GalleryDownloadItem(
                gallery: gallery,
                completedPages: gallery.files.count,
                state: .downloaded
            )
        }
    }
}

actor GalleryDownloadService {
    private let downloadsURL: URL
    private let fileManager = FileManager.default
    private let resolver = HitomiImageResolver()
    private let cache = ReaderImageCache()

    init(downloadsURL: URL) {
        self.downloadsURL = downloadsURL
    }

    // 完成済みフォルダと再開用の一時フォルダをまとめて削除する
    func delete(galleryID: String) throws {
        let partialURL = downloadsURL.appendingPathComponent(
            ".\(galleryID).partial",
            isDirectory: true
        )
        let completedURL = downloadsURL.appendingPathComponent(
            galleryID,
            isDirectory: true
        )

        for directoryURL in [partialURL, completedURL] {
            if fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.removeItem(at: directoryURL)
            }
        }
    }

    // 失敗時に一時フォルダを残し、再試行時は保存済みページを再利用する
    func download(
        _ gallery: GalleryInfo,
        progress: @escaping @Sendable (Int) async -> Void
    ) async throws {
        let partialURL = downloadsURL.appendingPathComponent(
            ".\(gallery.id).partial",
            isDirectory: true
        )
        let completedURL = downloadsURL.appendingPathComponent(
            gallery.id,
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: partialURL,
            withIntermediateDirectories: true
        )
        try writeMetadata(for: gallery, to: partialURL)

        let numberWidth = max(4, String(gallery.files.count).count)
        var completedPages = 0

        for (index, file) in gallery.files.enumerated() {
            try Task.checkCancellation()

            let pageURL = partialURL.appendingPathComponent(
                String(format: "%0*d.avif", numberWidth, index + 1)
            )

            if fileManager.fileExists(atPath: pageURL.path) {
                completedPages += 1
                await progress(completedPages)
                continue
            }

            let data = try await resolver.imageData(
                for: file.hash,
                cache: cache
            )
            try Task.checkCancellation()
            try data.write(to: pageURL, options: .atomic)
            await cache.removeData(for: file.hash)

            completedPages += 1
            await progress(completedPages)
        }

        if fileManager.fileExists(atPath: completedURL.path) {
            try fileManager.removeItem(at: completedURL)
        }

        try fileManager.moveItem(at: partialURL, to: completedURL)
    }

    private func writeMetadata(
        for gallery: GalleryInfo,
        to directoryURL: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = try encoder.encode(gallery)
        try metadata.write(
            to: directoryURL.appendingPathComponent("gallery.json"),
            options: .atomic
        )

        let information = """
        Title: \(gallery.title)
        ID: \(gallery.id)
        Pages: \(gallery.files.count)
        """
        try Data(information.utf8).write(
            to: directoryURL.appendingPathComponent("info.txt"),
            options: .atomic
        )
    }
}
