import SwiftUI

struct GalleryDetailView: View {

    @EnvironmentObject private var settings: AppSettings
    @State private var networkMonitor = NetworkMonitor()

    let gallery: GalleryInfo

    @State private var showReader = false
    @State private var showCellularWarning = false

    private let cellularWarningPageThreshold = 100
    private let veryLargeGalleryPageThreshold = 1000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                thumbnail

                Text(gallery.title)
                    .font(.title2.bold())

                informationSection

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
        .alert(cellularWarningTitle, isPresented: $showCellularWarning) {
            Button(cancelTitle, role: .cancel) {
            }

            Button(continueTitle) {
                showReader = true
            }
        } message: {
            Text(cellularWarningMessage)
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
            infoRow(title: "ID", value: gallery.id)

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

    // MARK: - Reader Navigation

    // モバイル通信かつページ数が多い場合だけ警告を表示する
    private func handleReadButton() {
        let shouldWarn =
            networkMonitor.connectionType == .cellular &&
            gallery.files.count >= cellularWarningPageThreshold

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

    private var cellularWarningTitle: String {
        let isVeryLarge = gallery.files.count >= veryLargeGalleryPageThreshold

        switch settings.galleryLanguage {
        case .english:
            return isVeryLarge ? "Very Large Gallery" : "Mobile Data Warning"
        case .japanese:
            return isVeryLarge ? "非常に大きな作品です" : "モバイルデータ通信に注意"
        case .korean:
            return isVeryLarge ? "매우 큰 작품입니다" : "모바일 데이터 사용 주의"
        }
    }

    private var cellularWarningMessage: String {
        let pages = gallery.files.count
        let isVeryLarge = pages >= veryLargeGalleryPageThreshold

        switch settings.galleryLanguage {

        case .english:
            if isVeryLarge {
                return """
                This gallery has \(pages) pages. Mobile data usage may be very high. Wi‑Fi is recommended when possible.
                """
            }

            if settings.preloadAllReaderImages {
                return """
                This gallery has \(pages) pages. Smooth Reading Mode is enabled, so all images will be preloaded in the background and may use a significant amount of mobile data.
                """
            }

            return """
            This gallery has \(pages) pages. Reading it over a cellular connection may use a significant amount of mobile data.
            """

        case .japanese:
            if isVeryLarge {
                return """
                この作品は\(pages)ページあります。モバイルデータ通信量が非常に多くなる可能性があります。可能であればWi‑Fi環境での利用をおすすめします。
                """
            }

            if settings.preloadAllReaderImages {
                return """
                この作品は\(pages)ページあります。現在は快適モードが有効なため、すべての画像をバックグラウンドで事前に読み込みます。モバイルデータ通信量が多くなる可能性があります。
                """
            }

            return """
            この作品は\(pages)ページあります。モバイル通信で閲覧すると、データ通信量が多くなる可能性があります。
            """
        case .korean:
            if isVeryLarge {
                return """
                이 작품은 \(pages)페이지입니다. 모바일 데이터 사용량이 매우 많을 수 있습니다. 가능하면 Wi‑Fi 환경에서 이용하는 것을 권장합니다.
                """
            }

            if settings.preloadAllReaderImages {
                return """
                이 작품은 \(pages)페이지입니다. 현재 쾌적 모드가 켜져 있어 모든 이미지를 백그라운드에서 미리 불러옵니다. 모바일 데이터를 많이 사용할 수 있습니다.
                """
            }

            return """
            이 작품은 \(pages)페이지입니다. 모바일 데이터로 읽을 경우 데이터 사용량이 많아질 수 있습니다.
            """
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

    private var continueTitle: String {
        switch settings.galleryLanguage {
        case .english:
            return "Continue"
        case .japanese:
            return "続けて読む"
        case .korean:
            return "계속 읽기"
        }
    }
}
