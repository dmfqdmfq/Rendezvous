import SwiftUI
import UIKit

nonisolated private func debugLog(_ message: String) {
#if DEBUG
    Swift.print(message)
#endif
}


struct GalleryReaderView: View {

    @EnvironmentObject private var settings: AppSettings

    let gallery: GalleryInfo

    @State private var resolver = HitomiImageResolver()
    @State private var cache = ReaderImageCache()

    @State private var isReady = false
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var currentPageID: Int?
    @State private var loadedHashes: Set<String> = []

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView(
                    "読み込みエラー",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if !isReady {
                loadingView
            } else {
                reader
            }
        }
        .background(.black)
        .safeAreaInset(edge: .top, spacing: 0) {
            readerHeader
        }
        // 標準ナビゲーションバーは非表示にし、Reader専用ヘッダーを使用する
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // ナビゲーションバーを隠してもiOS標準の戻るスワイプを有効にする
        .background {
            SwipeBackEnabler()
                .frame(width: 0, height: 0)
        }
        .task {
            await prepareReader()
        }
        .onDisappear {
            Task {
                await cache.cancelAllInFlight()
            }
        }
    }

    // MARK: - Header

    private var readerHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(gallery.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text("\(currentPage) / \(gallery.files.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // 快適モードの場合だけ全ページの事前読み込み進捗を表示する
            if settings.preloadAllReaderImages {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.15))

                        Rectangle()
                            .fill(.red)
                            .frame(width: geometry.size.width * loadingProgress)
                    }
                }
                .frame(height: 2)
            }
        }
        .background(.black)
    }

    private var loadingProgress: CGFloat {
        guard !gallery.files.isEmpty else {
            return 0
        }

        return CGFloat(loadedHashes.count) / CGFloat(gallery.files.count)
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ProgressView()
                .tint(.white)
        }
    }

    // MARK: - Reader

    private var reader: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(gallery.files.enumerated()), id: \.offset) { index, file in
                    ReaderPageView(
                        pageNumber: index + 1,
                        totalPages: gallery.files.count,
                        file: file,
                        resolver: resolver,
                        cache: cache,
                        preloadEnabled: settings.preloadAllReaderImages
                    ) {
                        markLoaded(file.hash)
                    }
                    .id(index + 1)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $currentPageID, anchor: .center)
        .onChange(of: currentPageID) { _, newValue in
            if let newValue {
                currentPage = newValue
            }
        }
        .background(.black)
        .onAppear {
            if currentPageID == nil {
                currentPageID = 1
            }
        }
    }

    // MARK: - Initialization

    // Readerを先に表示し、必要な場合は全ページの事前読み込みを並行して続ける
    private func prepareReader() async {
        do {
            try await resolver.initialize()

            guard !Task.isCancelled else {
                return
            }

            // gg.js の準備が終わった時点ですぐReaderを表示する
            isReady = true

            if settings.preloadAllReaderImages {
                await preloadAllImages()
            }
        } catch is CancellationError {
            return
        } catch {
            debugLog("[Reader] Initialize ERROR: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // 全ページを先頭から順番に取得し、一時的な通信エラーは最大2回まで再試行する
    private func preloadAllImages() async {
        for file in gallery.files {
            guard !Task.isCancelled else {
                return
            }

            if await cache.contains(file.hash) {
                markLoaded(file.hash)
                continue
            }

            do {
                let data = try await preloadDataWithRetry(for: file)
                markLoaded(file.hash)

                debugLog(
                    "[Reader][Preload] SUCCESS: \(file.name) Bytes=\(data.count)"
                )
            } catch is CancellationError {
                return
            } catch let error as URLError where error.code == .cancelled {
                return
            } catch {
                debugLog(
                    "[Reader][Preload] ERROR: \(file.name) \(error)"
                )
            }
        }
    }

    // 事前読み込み用の通信を必要に応じて再試行する
    private func preloadDataWithRetry(for file: GalleryFile) async throws -> Data {
        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            do {
                return try await resolver.imageData(
                    for: file.hash,
                    cache: cache
                )
            } catch {
                guard
                    attempt < maxAttempts,
                    shouldRetry(error)
                else {
                    throw error
                }

                let delay = UInt64(attempt) * 500_000_000

                debugLog(
                    "[Reader][Preload] RETRY: \(file.name) \(attempt)/\(maxAttempts - 1)"
                )

                try await Task.sleep(nanoseconds: delay)
            }
        }

        throw CancellationError()
    }

    // 一時的なネットワークエラーまたはサーバーエラーだけを自動再試行する
    private func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .resourceUnavailable:
                return true
            default:
                return false
            }
        }

        if let cacheError = error as? ReaderImageCache.CacheError {
            switch cacheError {
            case .httpError(let statusCode):
                return statusCode == 408 ||
                    statusCode == 429 ||
                    (500...599).contains(statusCode)
            case .invalidHTTPResponse:
                return true
            }
        }

        return false
    }

    // 同じページを重複して数えないように読み込み済み状態を記録する
    private func markLoaded(_ hash: String) {
        loadedHashes.insert(hash)
    }
}

// MARK: - Reader Page

private struct ReaderPageView: View {

    @EnvironmentObject private var settings: AppSettings

    let pageNumber: Int
    let totalPages: Int
    let file: GalleryFile
    let resolver: HitomiImageResolver
    let cache: ReaderImageCache
    let preloadEnabled: Bool
    let onLoaded: () -> Void

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 4) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if loadFailed {
                failedView
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(height: 300)
            }
        }
        .task {
            await loadImage()
        }
    }

    // MARK: - Failed View

    private var failedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(failedTitle)
                .font(.subheadline)
                .foregroundStyle(.white)

            Button {
                loadFailed = false

                Task {
                    await loadImage()
                }
            } label: {
                Label(retryTitle, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    // MARK: - Image Loading

    // キャッシュがあれば即座に表示し、なければ最大2回まで自動再試行する
    private func loadImage() async {
        if let cachedData = await cache.data(for: file.hash) {
            displayImage(from: cachedData, source: "CACHE HIT")
            return
        }

        loadFailed = false

        debugLog(
            "[Reader][Page \(pageNumber)] name=\(file.name) hasAVIF=\(file.hasAVIF ?? 0)"
        )

        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            do {
                let data = try await fetchImageData()

                displayImage(
                    from: data,
                    source: preloadEnabled ? "SHARED LOAD" : "NETWORK"
                )
                return
            } catch is CancellationError {
                return
            } catch let error as URLError where error.code == .cancelled {
                return
            } catch {
                let canRetry = attempt < maxAttempts && shouldRetry(error)

                if canRetry {
                    debugLog(
                        "[Reader][Page \(pageNumber)] RETRY: \(attempt)/\(maxAttempts - 1) \(error)"
                    )

                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(attempt) * 500_000_000
                        )
                    } catch {
                        return
                    }

                    continue
                }

                debugLog("[Reader][Page \(pageNumber)] ERROR: \(error)")
                loadFailed = true
                return
            }
        }
    }

    // 通常表示と事前読み込みの両方で同じ404復旧処理と共有キャッシュを使用する
    private func fetchImageData() async throws -> Data {
        try await resolver.imageData(
            for: file.hash,
            cache: cache
        )
    }

    // 一時的な通信障害だけを自動再試行する
    private func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .resourceUnavailable:
                return true
            default:
                return false
            }
        }

        if let cacheError = error as? ReaderImageCache.CacheError {
            switch cacheError {
            case .httpError(let statusCode):
                return statusCode == 408 ||
                    statusCode == 429 ||
                    (500...599).contains(statusCode)
            case .invalidHTTPResponse:
                return true
            }
        }

        return false
    }

    // 取得済みデータをUIImageへ変換して表示する
    private func displayImage(from data: Data, source: String) {
        guard let loadedImage = UIImage(data: data) else {
            debugLog("[Reader][Page \(pageNumber)] ERROR: 画像のデコードに失敗しました")
            loadFailed = true
            return
        }

        image = loadedImage
        onLoaded()

        debugLog(
            "[Reader][Page \(pageNumber)] \(source): \(Int(loadedImage.size.width))x\(Int(loadedImage.size.height))"
        )
    }

    // MARK: - Localization

    private var failedTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "이미지를 불러오지 못했습니다"
        case .english:
            return "Failed to Load Image"
        case .japanese:
            return "画像を読み込めませんでした"
        }
    }

    private var retryTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "재시도"
        case .english:
            return "Retry"
        case .japanese:
            return "再試行"
        }
    }
}
