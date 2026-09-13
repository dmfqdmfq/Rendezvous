import Foundation
import Combine

@MainActor
final class GalleryListViewModel: ObservableObject {

    @Published private(set) var galleries: [GalleryInfo] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMorePages = true
    @Published private(set) var submittedSearchQuery: String?
    @Published var errorMessage: String?

    private let indexService = HitomiIndexService()
    private let galleryService = HitomiGalleryService()
    private let searchService = HitomiSearchService()

    private var currentLanguage: GalleryLanguage?
    private var searchResultIDs: [Int]?
    private var nextPage = 1
    private var currentLoadID = UUID()
    private var loadMoreTask: Task<Void, Never>?

    // 一度に取得するギャラリー情報の最大並列数
    private let maxConcurrentGalleryRequests = 6

    // 次ページを先読みし始める残り件数
    private let preloadDistance = 10

    private let pageSize = 25

    var isSearchActive: Bool {
        submittedSearchQuery != nil
    }

    var availableTags: [GalleryTag] {
        galleries.flatMap { $0.tags ?? [] }
    }

    // MARK: - Initial Load

    // 言語変更時は現在の検索条件を保ったまま一覧を読み直す
    func reload(language: GalleryLanguage) async {
        if let submittedSearchQuery {
            await search(
                query: submittedSearchQuery,
                language: language
            )
        } else {
            await load(language: language)
        }
    }

    // 初回起動時や言語変更時に一覧を最初から読み込む
    func load(language: GalleryLanguage, page: Int = 1) async {
        loadMoreTask?.cancel()
        loadMoreTask = nil

        let loadID = UUID()

        currentLoadID = loadID
        currentLanguage = language
        submittedSearchQuery = nil
        searchResultIDs = nil
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
            hasMorePages = newGalleries.count >= pageSize
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

    // MARK: - 検索

    // 数字だけなら作品ID、それ以外はタイトルとタグ条件として検索する
    func search(query: String, language: GalleryLanguage) async {
        let normalizedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedQuery.isEmpty else {
            await load(language: language)
            return
        }

        loadMoreTask?.cancel()
        loadMoreTask = nil

        let loadID = UUID()

        currentLoadID = loadID
        currentLanguage = language
        submittedSearchQuery = normalizedQuery
        searchResultIDs = []
        nextPage = 1
        hasMorePages = false

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
            let ids: [Int]

            if normalizedQuery.allSatisfy(\.isNumber) {
                if let galleryID = Int(normalizedQuery) {
                    ids = [galleryID]
                } else {
                    ids = []
                }
            } else {
                ids = try await searchService.galleryIDs(
                    matching: normalizedQuery,
                    language: language
                )
            }

            guard currentLoadID == loadID else {
                return
            }

            searchResultIDs = ids
            let firstPageIDs = Array(ids.prefix(pageSize))
            let searchGalleries = try await fetchGalleries(
                ids: firstPageIDs,
                loadID: loadID
            )

            guard currentLoadID == loadID else {
                return
            }

            galleries = searchGalleries
            nextPage = 2
            hasMorePages = ids.count > pageSize
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            guard currentLoadID == loadID else {
                return
            }

#if DEBUG
            print("[GalleryList] Search ERROR:", error)
#endif
            errorMessage = searchErrorMessage(for: language)
        }
    }

    // MARK: - Refresh

    // 現在の一覧を表示したまま1ページ目だけ最新状態へ更新する
    func refresh(language: GalleryLanguage) async {
        if let submittedSearchQuery {
            await search(
                query: submittedSearchQuery,
                language: language
            )
            return
        }

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
            hasMorePages = refreshedGalleries.count >= pageSize
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

            hasMorePages = hasPage(
                after: page,
                loadedCount: newGalleries.count
            )
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
        let ids: [Int]

        if let searchResultIDs {
            let startIndex = (page - 1) * pageSize

            guard startIndex < searchResultIDs.count else {
                return []
            }

            let endIndex = min(startIndex + pageSize, searchResultIDs.count)
            ids = Array(searchResultIDs[startIndex..<endIndex])
        } else {
            ids = try await indexService.fetchGalleryIDs(
                language: language,
                page: page
            )
        }

        guard currentLoadID == loadID else {
            throw CancellationError()
        }

        return try await fetchGalleries(ids: ids, loadID: loadID)
    }

    // 指定したIDのメタデータを最大6件ずつ並列取得し、元の並び順を維持する
    private func fetchGalleries(
        ids: [Int],
        loadID: UUID
    ) async throws -> [GalleryInfo] {

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

    private func hasPage(after page: Int, loadedCount: Int) -> Bool {
        guard let searchResultIDs else {
            return loadedCount >= pageSize
        }

        return page * pageSize < searchResultIDs.count
    }

    private func searchErrorMessage(for language: GalleryLanguage) -> String {
        switch language {
        case .english:
            return "Could not load the search results."
        case .japanese:
            return "検索結果を読み込めませんでした。"
        case .korean:
            return "검색 결과를 불러오지 못했습니다."
        }
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
