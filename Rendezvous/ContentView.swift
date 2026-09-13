import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: GalleryLibraryStore
    @StateObject private var viewModel = GalleryListViewModel()
    @StateObject private var searchViewModel = GallerySearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var networkMonitor = NetworkMonitor()
    @State private var selectedReaderGallery: GalleryInfo?
    @State private var selectedDetailGallery: GalleryInfo?
    @State private var showReader = false
    @State private var showGalleryDetail = false
    @State private var showCellularWarning = false
    @State private var isShowingFavorites = false

    var body: some View {
        Group {
            if viewModel.isLoading,
               viewModel.galleries.isEmpty,
               !viewModel.isSearchActive {
                // 初回読み込み中はナビゲーションUIを表示しない
                StartupLoadingView()
            } else {
                mainView
            }
        }
        .task(id: settings.galleryLanguage.rawValue) {
            // 言語が変わった場合は1ページ目から読み直す
            await viewModel.reload(language: settings.galleryLanguage)
        }
    }

    // MARK: - Main View

    private var mainView: some View {
        NavigationStack {
            Group {
                if isShowingFavorites,
                   library.favorites.isEmpty {
                    ContentUnavailableView(
                        emptyFavoritesTitle,
                        systemImage: "star",
                        description: Text(emptyFavoritesDescription)
                    )
                } else if !isShowingFavorites,
                          viewModel.isLoading,
                          viewModel.galleries.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !isShowingFavorites,
                          let errorMessage = viewModel.errorMessage,
                          viewModel.galleries.isEmpty {
                    ContentUnavailableView(
                        loadErrorTitle,
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if !isShowingFavorites,
                          viewModel.isSearchActive,
                          viewModel.galleries.isEmpty {
                    ContentUnavailableView(
                        noSearchResultsTitle,
                        systemImage: "magnifyingglass",
                        description: Text(noSearchResultsDescription)
                    )
                } else {
                    galleryList
                }
            }
            .navigationTitle(
                isShowingFavorites
                    ? favoritesTitle
                    : settings.galleryLanguage.appTitle
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        DownloadsView()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .accessibilityLabel(downloadsTitle)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingFavorites = false
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(searchButtonTitle)

                    Button {
                        toggleFavoritesList()
                    } label: {
                        Image(
                            systemName: isShowingFavorites
                                ? "star.fill"
                                : "star"
                        )
                    }
                    .foregroundStyle(isShowingFavorites ? .yellow : .primary)
                    .accessibilityLabel(favoritesTitle)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(settingsTitle)
                }
            }
            .searchable(
                text: $searchViewModel.query,
                prompt: Text(searchPrompt)
            )
            .searchFocused($isSearchFocused)
            .searchSuggestions {
                ForEach(searchViewModel.suggestions) { suggestion in
                    Button {
                        // 候補は検索を開始せず、検索欄への追加だけを行う
                        searchViewModel.select(suggestion)
                    } label: {
                        TagSuggestionRow(suggestion: suggestion)
                    }
                }
            }
            .onSubmit(of: .search) {
                isShowingFavorites = false
                searchViewModel.clearSuggestions()

                Task {
                    await viewModel.search(
                        query: searchViewModel.query,
                        language: settings.galleryLanguage
                    )
                }
            }
            .onChange(of: searchViewModel.query) { _, newQuery in
                searchViewModel.updateSuggestions(
                    availableTags: viewModel.availableTags
                )

                if newQuery.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                   viewModel.isSearchActive {
                    Task {
                        await viewModel.load(
                            language: settings.galleryLanguage
                        )
                    }
                }
            }
            .navigationDestination(isPresented: $showReader) {
                if let selectedReaderGallery {
                    GalleryReaderView(gallery: selectedReaderGallery)
                }
            }
            .navigationDestination(isPresented: $showGalleryDetail) {
                if let selectedDetailGallery {
                    GalleryDetailView(gallery: selectedDetailGallery)
                }
            }
            .alert(readerWarning.title, isPresented: $showCellularWarning) {
                Button(readerWarning.cancelTitle, role: .cancel) {
                }

                Button(readerWarning.continueTitle) {
                    showReader = true
                }
            } message: {
                Text(readerWarning.message)
            }
        }
    }

    // MARK: - Gallery List

    private var galleryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(
                    Array(displayedGalleries.enumerated()),
                    id: \.element.id
                ) { index, gallery in
                    GalleryCardView(gallery: gallery)
                    .contentShape(Rectangle())
                    .gesture(gallerySelectionGesture(for: gallery))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(galleryCardAccessibilityHint)
                    .accessibilityAction {
                        openReader(for: gallery)
                    }
                    .accessibilityAction(named: Text(detailTitle)) {
                        openDetail(for: gallery)
                    }
                    .overlay(alignment: .topTrailing) {
                        GalleryCardActionButtons(gallery: gallery)
                            .padding(12)
                    }
                    .onAppear {
                        // セルのライフサイクルに依存する.taskは使用せず、
                        // ViewModel側で独立して次ページの先読みを管理する
                        if !isShowingFavorites {
                            viewModel.requestNextPageIfNeeded(
                                currentIndex: index,
                                language: settings.galleryLanguage
                            )
                        }
                    }
                }

                if viewModel.isLoadingMore, !isShowingFavorites {
                    ProgressView()
                        .padding(.vertical, 18)
                }
            }
            .padding()
        }
        .refreshable {
            // 一覧を残したまま最新の1ページ目へ更新する
            if !isShowingFavorites {
                await viewModel.refresh(
                    language: settings.galleryLanguage
                )
            }
        }
    }

    private var displayedGalleries: [GalleryInfo] {
        isShowingFavorites ? library.favorites : viewModel.galleries
    }

    // MARK: - 作品選択

    // 長押しを先に判定し、短いタップの場合だけReaderを開く
    private func gallerySelectionGesture(
        for gallery: GalleryInfo
    ) -> some Gesture {
        LongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 12
        )
        .exclusively(before: TapGesture())
        .onEnded { result in
            switch result {
            case .first:
                openDetail(for: gallery)
            case .second:
                openReader(for: gallery)
            }
        }
    }

    private func openReader(for gallery: GalleryInfo) {
        selectedReaderGallery = gallery

        let shouldWarn =
            networkMonitor.connectionType == .cellular &&
            gallery.files.count >= GalleryReaderWarning.pageThreshold

        if shouldWarn {
            showCellularWarning = true
        } else {
            showReader = true
        }
    }

    private func openDetail(for gallery: GalleryInfo) {
        selectedDetailGallery = gallery
        showGalleryDetail = true
    }

    private func toggleFavoritesList() {
        isShowingFavorites.toggle()
        isSearchFocused = false

        if isShowingFavorites {
            searchViewModel.query = ""
            searchViewModel.clearSuggestions()
        }
    }

    private var readerWarning: GalleryReaderWarning {
        GalleryReaderWarning(
            pageCount: selectedReaderGallery?.files.count ?? 0,
            language: settings.galleryLanguage,
            preloadAllImages: settings.preloadAllReaderImages
        )
    }

    // MARK: - Localization

    private var settingsTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Settings"
        case .japanese:
            return "設定"
        case .korean:
            return "설정"
        }
    }

    private var loadErrorTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Loading Error"
        case .japanese:
            return "読み込みエラー"
        case .korean:
            return "불러오기 오류"
        }
    }

    private var searchPrompt: String {
        switch settings.galleryLanguage {
        case .english:
            return "Title, tag, or gallery ID"
        case .japanese:
            return "タイトル、タグ、作品ID"
        case .korean:
            return "제목, 태그 또는 작품 번호"
        }
    }

    private var searchButtonTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Search"
        case .japanese:
            return "検索"
        case .korean:
            return "검색"
        }
    }

    private var noSearchResultsTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "No Results"
        case .japanese:
            return "検索結果がありません"
        case .korean:
            return "검색 결과가 없습니다"
        }
    }

    private var noSearchResultsDescription: String {
        let query = viewModel.submittedSearchQuery ?? searchViewModel.query

        switch settings.galleryLanguage {
        case .english:
            return "No galleries matched “\(query)”."
        case .japanese:
            return "「\(query)」に一致する作品はありません。"
        case .korean:
            return "‘\(query)’와 일치하는 작품이 없습니다."
        }
    }

    private var detailTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Show Gallery Info"
        case .japanese:
            return "作品情報を表示"
        case .korean:
            return "작품 정보 보기"
        }
    }

    private var galleryCardAccessibilityHint: String {
        switch settings.galleryLanguage {
        case .english:
            return "Tap to read. Touch and hold for gallery information."
        case .japanese:
            return "タップして読みます。長押しすると作品情報を表示します。"
        case .korean:
            return "탭하면 읽고, 길게 누르면 작품 정보를 표시합니다."
        }
    }

    private var favoritesTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Favorites"
        case .japanese:
            return "お気に入り"
        case .korean:
            return "즐겨찾기"
        }
    }

    private var emptyFavoritesTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "No Favorites"
        case .japanese:
            return "お気に入りはありません"
        case .korean:
            return "즐겨찾기가 없습니다"
        }
    }

    private var emptyFavoritesDescription: String {
        switch settings.galleryLanguage {
        case .english:
            return "Tap the star on a gallery to add it here."
        case .japanese:
            return "作品の星をタップすると、ここに追加されます。"
        case .korean:
            return "작품의 별을 누르면 여기에 추가됩니다."
        }
    }

    private var downloadsTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Downloads"
        case .japanese:
            return "ダウンロード"
        case .korean:
            return "다운로드"
        }
    }
}

// MARK: - タグ候補

private struct TagSuggestionRow: View {
    let suggestion: HitomiTagSuggestion

    var body: some View {
        HStack(spacing: 10) {
            Text(suggestion.queryToken)
                .foregroundStyle(color)

            Spacer()

            if let count = suggestion.count {
                Text(count, format: .number)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var color: Color {
        switch suggestion.namespace {
        case .male:
            return .blue
        case .female:
            return .pink
        case .tag:
            return .gray
        }
    }
}

// MARK: - 作品操作

private struct GalleryCardActionButtons: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: GalleryLibraryStore

    let gallery: GalleryInfo

    var body: some View {
        HStack(spacing: 7) {
            Button {
                library.toggleFavorite(gallery)
            } label: {
                Image(
                    systemName: library.isFavorite(gallery.id)
                        ? "star.fill"
                        : "star"
                )
                .foregroundStyle(
                    library.isFavorite(gallery.id)
                        ? .yellow
                        : .primary
                )
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoriteButtonTitle)

            Button {
                library.startDownload(gallery)
            } label: {
                Group {
                    switch downloadState {
                    case .downloading:
                        ProgressView()
                            .controlSize(.small)
                    case .downloaded:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failed:
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundStyle(.red)
                    case nil:
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(
                downloadState == .downloading ||
                downloadState == .downloaded
            )
            .accessibilityLabel(downloadButtonTitle)
        }
    }

    private var downloadState: GalleryDownloadItem.State? {
        library.downloadItem(for: gallery.id)?.state
    }

    private var favoriteButtonTitle: String {
        let isFavorite = library.isFavorite(gallery.id)

        switch settings.galleryLanguage {
        case .english:
            return isFavorite ? "Remove from Favorites" : "Add to Favorites"
        case .japanese:
            return isFavorite ? "お気に入りから削除" : "お気に入りに追加"
        case .korean:
            return isFavorite ? "즐겨찾기에서 제거" : "즐겨찾기에 추가"
        }
    }

    private var downloadButtonTitle: String {
        switch (settings.galleryLanguage, downloadState) {
        case (.english, .downloading):
            return "Downloading"
        case (.japanese, .downloading):
            return "ダウンロード中"
        case (.korean, .downloading):
            return "다운로드 중"
        case (.english, .downloaded):
            return "Downloaded"
        case (.japanese, .downloaded):
            return "ダウンロード済み"
        case (.korean, .downloaded):
            return "다운로드 완료"
        case (.english, .failed):
            return "Retry Download"
        case (.japanese, .failed):
            return "ダウンロードを再試行"
        case (.korean, .failed):
            return "다운로드 재시도"
        case (.english, nil):
            return "Download"
        case (.japanese, nil):
            return "ダウンロード"
        case (.korean, nil):
            return "다운로드"
        }
    }
}

// MARK: - Gallery Card

struct GalleryCardView: View {

    @EnvironmentObject private var settings: AppSettings

    let gallery: GalleryInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // 最初のページをサムネイルとして表示する
                if let firstFile = gallery.files.first {
                    HitomiThumbnailView(hash: firstFile.hash)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 90, height: 125)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(gallery.title)
                        .font(.headline)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .padding(.trailing, 78)

                    Spacer()

                    Text("ID: \(gallery.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        if let language = gallery.languageLocalname {
                            Text(language)
                        }

                        Spacer()

                        Text(pageCountText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(minHeight: 125)

            if let tags = gallery.tags, !tags.isEmpty {
                Divider()

                GalleryTagFlowView(tags: tags)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 4,
                    y: 2
                )
        }
    }

    private var pageCountText: String {
        switch settings.galleryLanguage {
        case .english:
            return "\(gallery.files.count) pages"
        case .japanese:
            return "\(gallery.files.count) ページ"
        case .korean:
            return "\(gallery.files.count) 페이지"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(GalleryLibraryStore())
}
