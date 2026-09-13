import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = GalleryListViewModel()
    @StateObject private var searchViewModel = GallerySearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var networkMonitor = NetworkMonitor()
    @State private var selectedReaderGallery: GalleryInfo?
    @State private var selectedDetailGallery: GalleryInfo?
    @State private var showReader = false
    @State private var showGalleryDetail = false
    @State private var showCellularWarning = false

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
                if viewModel.isLoading,
                   viewModel.galleries.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage,
                   viewModel.galleries.isEmpty {
                    ContentUnavailableView(
                        loadErrorTitle,
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.isSearchActive,
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
            .navigationTitle(settings.galleryLanguage.appTitle)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(searchButtonTitle)

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
                    Array(viewModel.galleries.enumerated()),
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
                    .onAppear {
                        // セルのライフサイクルに依存する.taskは使用せず、
                        // ViewModel側で独立して次ページの先読みを管理する
                        viewModel.requestNextPageIfNeeded(
                            currentIndex: index,
                            language: settings.galleryLanguage
                        )
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 18)
                }
            }
            .padding()
        }
        .refreshable {
            // 一覧を残したまま最新の1ページ目へ更新する
            await viewModel.refresh(
                language: settings.galleryLanguage
            )
        }
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
}
