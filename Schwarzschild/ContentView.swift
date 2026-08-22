import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = GalleryListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.galleries.isEmpty {
                    StartupLoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "読み込みエラー",
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
        .task(id: settings.galleryLanguage.rawValue) {
            // 言語設定が変更された場合、対応するギャラリー一覧を再読み込みする
            await viewModel.load(
                language: settings.galleryLanguage,
                page: 1
            )
        }
    }

    // 設定ボタンのアクセシビリティ用タイトル
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
}

// MARK: - Gallery Card

struct GalleryCardView: View {

    let gallery: GalleryInfo

    var body: some View {
        HStack(spacing: 14) {

            // サムネイル画像は次の段階で追加する
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
    // PreviewでもAppSettingsをEnvironmentObjectとして渡す
    .environmentObject(AppSettings())
}
