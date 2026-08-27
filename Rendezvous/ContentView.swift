import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = GalleryListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.galleries.isEmpty {
                // 初回読み込み中はナビゲーションUIを表示しない
                StartupLoadingView()
            } else {
                mainView
            }
        }
        .task(id: settings.galleryLanguage.rawValue) {
            // 言語が変わった場合は1ページ目から読み直す
            await viewModel.load(
                language: settings.galleryLanguage,
                page: 1
            )
        }
    }

    // MARK: - Main View

    private var mainView: some View {
        NavigationStack {
            Group {
                if let errorMessage = viewModel.errorMessage,
                   viewModel.galleries.isEmpty {
                    ContentUnavailableView(
                        loadErrorTitle,
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    galleryList
                }
            }
            .navigationTitle(settings.galleryLanguage.appTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(settingsTitle)
                }
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
                    NavigationLink {
                        GalleryDetailView(gallery: gallery)
                    } label: {
                        GalleryCardView(gallery: gallery)
                    }
                    .buttonStyle(.plain)
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
}

// MARK: - Gallery Card

struct GalleryCardView: View {

    @EnvironmentObject private var settings: AppSettings

    let gallery: GalleryInfo

    var body: some View {
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
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
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
