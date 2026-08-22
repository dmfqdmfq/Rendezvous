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
            // 言語設定に対応するギャラリー一覧を読み込む
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
                if let errorMessage = viewModel.errorMessage {
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
                ForEach(viewModel.galleries) { gallery in
                    NavigationLink {
                        GalleryDetailView(
                            gallery: gallery
                        )
                    } label: {
                        GalleryCardView(
                            gallery: gallery
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Localized Text

    private var settingsTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "설정"
        case .english:
            return "Settings"
        case .japanese:
            return "設定"
        }
    }

    private var loadErrorTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "불러오기 오류"
        case .english:
            return "Loading Error"
        case .japanese:
            return "読み込みエラー"
        }
    }
}

// MARK: - Gallery Card

struct GalleryCardView: View {

    let gallery: GalleryInfo

    var body: some View {
        HStack(spacing: 14) {

            // 最初のページをサムネイルとして表示する
            if let firstFile = gallery.files.first {
                HitomiThumbnailView(
                    hash: firstFile.hash
                )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
                    .frame(
                        width: 90,
                        height: 125
                    )
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

                    Text("\(gallery.files.count) pages")
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
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
