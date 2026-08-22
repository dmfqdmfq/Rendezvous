import Foundation
import Combine

@MainActor
final class GalleryListViewModel: ObservableObject {

    @Published private(set) var galleries: [GalleryInfo] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMorePages = true
    @Published var errorMessage: String?

    private let indexService = HitomiIndexService()
    private let galleryService = HitomiGalleryService()

    private var currentLanguage: GalleryLanguage?
    private var nextPage = 1
    private var currentLoadID = UUID()
    private var loadMoreTask: Task<Void, Never>?

    // 一度に取得するギャラリー情報の最大並列数
    private let maxConcurrentGalleryRequests = 6

    // 次ページを先読みし始める残り件数
    private let preloadDistance = 10

    // MARK: - Initial Load

    // 初回起動時や言語変更時に一覧を最初から読み込む
    func load(language: GalleryLanguage, page: Int = 1) async {
        loadMoreTask?.cancel()
        loadMoreTask = nil

        let loadID = UUID()

        currentLoadID = loadID
        currentLanguage = language
        nextPage = page
        hasMorePages = true

        galleries.removeAll()
        errorMessage = nil
        isLoading = true
        isLoadingMore = false

        defer {
            if currentLoadID == loadID {
                isLoading = false
            }
        }

        do {
            let newGalleries = try await fetchPage(
                language: language,
                page: page,
                loadID: loadID
            )

            guard currentLoadID == loadID else {
                return
            }

            galleries = newGalleries
            nextPage = page + 1
            hasMorePages = newGalleries.count >= 25
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard currentLoadID == loadID else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh

    // 現在の一覧を表示したまま1ページ目だけ最新状態へ更新する
    func refresh(language: GalleryLanguage) async {
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingMore = false

        let loadID = UUID()

        currentLoadID = loadID
        currentLanguage = language
        errorMessage = nil

        do {
            let refreshedGalleries = try await fetchPage(
                language: language,
                page: 1,
                loadID: loadID
            )

            guard currentLoadID == loadID,
                  currentLanguage == language else {
                return
            }

            galleries = refreshedGalleries
            nextPage = 2
            hasMorePages = refreshedGalleries.count >= 25
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
#if DEBUG
            print("[GalleryList] Refresh ERROR:", error)
#endif
            // 更新に失敗しても現在表示中の一覧はそのまま維持する
        }
    }

    // MARK: - Infinite Scroll Trigger

    // セルの表示状態とは独立したTaskで次ページの先読みを開始する
    func requestNextPageIfNeeded(
        currentIndex: Int,
        language: GalleryLanguage
    ) {
        guard !isLoading,
              !isLoadingMore,
              hasMorePages,
              currentLanguage == language,
              loadMoreTask == nil else {
            return
        }

        let triggerIndex = max(
            galleries.count - preloadDistance,
            0
        )

        guard currentIndex >= triggerIndex else {
            return
        }

        loadMoreTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadNextPage(language: language)
            self.loadMoreTask = nil
        }
    }

    // MARK: - Infinite Scroll

    // 次の25件を追加で読み込む
    private func loadNextPage(language: GalleryLanguage) async {
        guard !isLoading,
              !isLoadingMore,
              hasMorePages,
              currentLanguage == language else {
            return
        }

        let loadID = currentLoadID
        let page = nextPage

        isLoadingMore = true

        defer {
            if currentLoadID == loadID {
                isLoadingMore = false
            }
        }

        do {
            let newGalleries = try await fetchPage(
                language: language,
                page: page,
                loadID: loadID
            )

            guard currentLoadID == loadID,
                  currentLanguage == language else {
                return
            }

            if newGalleries.isEmpty {
                hasMorePages = false
                return
            }

            let existingIDs = Set(galleries.map(\.id))
            let uniqueGalleries = newGalleries.filter {
                !existingIDs.contains($0.id)
            }

            galleries.append(contentsOf: uniqueGalleries)
            nextPage = page + 1

            if newGalleries.count < 25 {
                hasMorePages = false
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
#if DEBUG
            print("[GalleryList] Load more ERROR:", error)
#endif
        }
    }

    // MARK: - Page Loading

    // 25件のメタデータを最大6件ずつ並列取得し、元の並び順を維持する
    private func fetchPage(
        language: GalleryLanguage,
        page: Int,
        loadID: UUID
    ) async throws -> [GalleryInfo] {
        let ids = try await indexService.fetchGalleryIDs(
            language: language,
            page: page
        )

        guard currentLoadID == loadID else {
            throw CancellationError()
        }

        var results: [(index: Int, gallery: GalleryInfo)] = []
        results.reserveCapacity(ids.count)

        var nextIndex = 0

        try await withThrowingTaskGroup(
            of: (Int, GalleryInfo?).self
        ) { group in

            while nextIndex < min(maxConcurrentGalleryRequests, ids.count) {
                addGalleryTask(
                    to: &group,
                    id: ids[nextIndex],
                    index: nextIndex
                )
                nextIndex += 1
            }

            while let (index, gallery) = try await group.next() {
                try Task.checkCancellation()

                guard currentLoadID == loadID else {
                    group.cancelAll()
                    throw CancellationError()
                }

                if let gallery {
                    results.append((index, gallery))
                }

                if nextIndex < ids.count {
                    addGalleryTask(
                        to: &group,
                        id: ids[nextIndex],
                        index: nextIndex
                    )
                    nextIndex += 1
                }
            }
        }

        return results
            .sorted { $0.index < $1.index }
            .map(\.gallery)
    }

    // ギャラリー1件を取得するTaskをグループへ追加する
    private func addGalleryTask(
        to group: inout ThrowingTaskGroup<(Int, GalleryInfo?), any Error>,
        id: Int,
        index: Int
    ) {
        let galleryService = galleryService

        group.addTask {
            do {
                let gallery = try await galleryService.fetchGallery(
                    id: String(id)
                )

                return (index, gallery)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                // スクロールや言語変更によってキャンセルされた通信はエラーとして扱わない
                throw CancellationError()
            } catch {
#if DEBUG
                print("[GalleryList][\(id)] ERROR:", error)
#endif
                return (index, nil)
            }
        }
    }
}
