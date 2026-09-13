import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: GalleryLibraryStore
    @State private var pendingDeletion: GalleryDownloadItem?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Group {
            if library.downloads.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "arrow.down.circle",
                    description: Text(emptyDescription)
                )
            } else {
                List(library.downloads) { item in
                    DownloadRow(item: item) {
                        pendingDeletion = item
                        isShowingDeleteConfirmation = true
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            deleteConfirmationTitle,
            isPresented: $isShowingDeleteConfirmation,
            presenting: pendingDeletion
        ) { item in
            Button(deleteTitle, role: .destructive) {
                pendingDeletion = nil

                Task {
                    await library.deleteDownload(item.id)
                }
            }

            Button(cancelTitle, role: .cancel) {
                pendingDeletion = nil
            }
        } message: { item in
            Text(deleteConfirmationMessage(for: item.gallery.title))
        }
    }

    private var title: String {
        switch settings.galleryLanguage {
        case .english:
            return "Downloads"
        case .japanese:
            return "ダウンロード"
        case .korean:
            return "다운로드"
        }
    }

    private var emptyTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "No Downloads"
        case .japanese:
            return "ダウンロードはありません"
        case .korean:
            return "다운로드가 없습니다"
        }
    }

    private var emptyDescription: String {
        switch settings.galleryLanguage {
        case .english:
            return "Downloaded galleries will appear here."
        case .japanese:
            return "ダウンロードした作品がここに表示されます。"
        case .korean:
            return "다운로드한 작품이 여기에 표시됩니다."
        }
    }

    private var deleteConfirmationTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Delete Download?"
        case .japanese:
            return "ダウンロードを削除しますか？"
        case .korean:
            return "다운로드를 삭제할까요?"
        }
    }

    private func deleteConfirmationMessage(for galleryTitle: String) -> String {
        switch settings.galleryLanguage {
        case .english:
            return "“\(galleryTitle)” and its downloaded files will be removed."
        case .japanese:
            return "「\(galleryTitle)」とダウンロード済みファイルを削除します。"
        case .korean:
            return "‘\(galleryTitle)’ 및 다운로드한 파일을 삭제합니다."
        }
    }

    private var deleteTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Delete"
        case .japanese:
            return "削除"
        case .korean:
            return "삭제"
        }
    }

    private var cancelTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Cancel"
        case .japanese:
            return "キャンセル"
        case .korean:
            return "취소"
        }
    }
}

private struct DownloadRow: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: GalleryLibraryStore

    let item: GalleryDownloadItem
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let firstFile = item.gallery.files.first {
                HitomiThumbnailView(
                    hash: firstFile.hash,
                    width: 60,
                    height: 84
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.gallery.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("ID: \(item.gallery.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                downloadStatus
            }

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                if let directoryURL = library.downloadedDirectoryURL(
                    for: item.id
                ) {
                    NavigationLink {
                        GalleryReaderView(
                            gallery: item.gallery,
                            localPagesDirectory: directoryURL
                        )
                    } label: {
                        Image(systemName: "book.pages")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(readTitle)
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(deleteTitle)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var downloadStatus: some View {
        switch item.state {
        case .downloading:
            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: item.progress)

                HStack {
                    Text("\(item.completedPages) / \(item.gallery.files.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(cancelTitle) {
                        library.cancelDownload(item.id)
                    }
                    .font(.caption)
                }
            }

        case .downloaded:
            Label(savedTitle, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)

            Text("Downloads/\(item.gallery.id)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

        case .failed:
            HStack {
                Label(failedTitle, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)

                Spacer()

                Button(retryTitle) {
                    library.startDownload(item.gallery)
                }
                .font(.caption)
            }
        }
    }

    private var cancelTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Cancel"
        case .japanese:
            return "キャンセル"
        case .korean:
            return "취소"
        }
    }

    private var savedTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Saved in Files"
        case .japanese:
            return "ファイルに保存済み"
        case .korean:
            return "파일 앱에 저장됨"
        }
    }

    private var failedTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Download failed"
        case .japanese:
            return "ダウンロード失敗"
        case .korean:
            return "다운로드 실패"
        }
    }

    private var retryTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Retry"
        case .japanese:
            return "再試行"
        case .korean:
            return "재시도"
        }
    }

    private var readTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Read Download"
        case .japanese:
            return "ダウンロードを読む"
        case .korean:
            return "다운로드 읽기"
        }
    }

    private var deleteTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Delete Download"
        case .japanese:
            return "ダウンロードを削除"
        case .korean:
            return "다운로드 삭제"
        }
    }
}
