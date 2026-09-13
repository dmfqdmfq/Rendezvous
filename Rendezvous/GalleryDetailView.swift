import SwiftUI
import UIKit

struct GalleryDetailView: View {

    @EnvironmentObject private var settings: AppSettings
    @State private var networkMonitor = NetworkMonitor()

    let gallery: GalleryInfo

    @State private var showReader = false
    @State private var showCellularWarning = false
    @State private var didCopyGalleryID = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                thumbnail

                Text(gallery.title)
                    .font(.title2.bold())

                informationSection

                if !tags.isEmpty {
                    GalleryTagListView(
                        title: tagsTitle,
                        tags: tags
                    )
                }

                if !gallery.files.isEmpty {
                    pageThumbnailsSection
                }

                Button {
                    handleReadButton()
                } label: {
                    Text(settings.galleryLanguage.readButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReader) {
            GalleryReaderView(gallery: gallery)
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
        .task(id: didCopyGalleryID) {
            guard didCopyGalleryID else {
                return
            }

            try? await Task.sleep(for: .seconds(1.5))

            guard !Task.isCancelled else {
                return
            }

            didCopyGalleryID = false
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        if let firstFile = gallery.files.first {
            HStack {
                Spacer()

                HitomiThumbnailView(hash: firstFile.hash)
                    .scaleEffect(1.45)
                    .padding(.vertical, 30)

                Spacer()
            }
        }
    }

    // MARK: - Information

    private var informationSection: some View {
        VStack(spacing: 0) {
            galleryIDRow

            Divider()

            infoRow(
                title: languageTitle,
                value: gallery.languageLocalname ?? gallery.language ?? "-"
            )

            Divider()

            infoRow(
                title: pagesTitle,
                value: "\(gallery.files.count)"
            )
        }
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.secondary.opacity(0.08))
        }
    }

    private var galleryIDRow: some View {
        HStack {
            Text("ID")
                .foregroundStyle(.secondary)

            Spacer()

            Text(gallery.id)
                .monospacedDigit()

            Button {
                UIPasteboard.general.string = gallery.id
                didCopyGalleryID = true
            } label: {
                Image(
                    systemName: didCopyGalleryID
                        ? "checkmark"
                        : "doc.on.doc"
                )
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(didCopyGalleryID ? .green : .accentColor)
            .accessibilityLabel(
                didCopyGalleryID
                    ? galleryIDCopiedTitle
                    : copyGalleryIDTitle
            )
        }
        .padding(.vertical, 8)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }

    // MARK: - タグ

    private var tags: [GalleryTag] {
        gallery.tags ?? []
    }

    // MARK: - ページサムネイル

    private var pageThumbnailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pageThumbnailsTitle)
                .font(.headline)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 10),
                    count: 3
                ),
                spacing: 10
            ) {
                ForEach(
                    Array(gallery.files.prefix(9).enumerated()),
                    id: \.offset
                ) { index, file in
                    HitomiThumbnailView(
                        hash: file.hash,
                        kind: .page,
                        width: nil,
                        height: 145
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(index + 1)")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.68), in: Capsule())
                            .padding(6)
                    }
                    .accessibilityLabel(
                        pageThumbnailAccessibilityLabel(index + 1)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reader Navigation

    private var readerWarning: GalleryReaderWarning {
        GalleryReaderWarning(
            pageCount: gallery.files.count,
            language: settings.galleryLanguage,
            preloadAllImages: settings.preloadAllReaderImages
        )
    }

    // モバイル通信かつページ数が多い場合だけ警告を表示する
    private func handleReadButton() {
        let shouldWarn =
            networkMonitor.connectionType == .cellular &&
            gallery.files.count >= GalleryReaderWarning.pageThreshold

        if shouldWarn {
            showCellularWarning = true
        } else {
            showReader = true
        }
    }

    // MARK: - Localization

    private var detailTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Gallery Info"
        case .japanese:
            return "作品情報"
        case .korean:
            return "작품 정보"
        }
    }

    private var languageTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Language"
        case .japanese:
            return "言語"
        case .korean:
            return "언어"
        }
    }

    private var pagesTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Pages"
        case .japanese:
            return "ページ"
        case .korean:
            return "페이지"
        }
    }

    private var tagsTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Tags"
        case .japanese:
            return "タグ"
        case .korean:
            return "태그"
        }
    }

    private var pageThumbnailsTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Page Thumbnails"
        case .japanese:
            return "ページサムネイル"
        case .korean:
            return "페이지 미리보기"
        }
    }

    private func pageThumbnailAccessibilityLabel(_ page: Int) -> String {
        switch settings.galleryLanguage {
        case .english:
            return "Page \(page) thumbnail"
        case .japanese:
            return "\(page)ページ目のサムネイル"
        case .korean:
            return "\(page)페이지 미리보기"
        }
    }

    private var copyGalleryIDTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Copy Gallery ID"
        case .japanese:
            return "作品IDをコピー"
        case .korean:
            return "작품 ID 복사"
        }
    }

    private var galleryIDCopiedTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Gallery ID Copied"
        case .japanese:
            return "作品IDをコピーしました"
        case .korean:
            return "작품 ID를 복사했습니다"
        }
    }

}
