import SwiftUI

enum ReaderViewMode: String, CaseIterable, Identifiable {
    case basicSlide
    case book

    var id: String {
        rawValue
    }
}

enum BookReadingDirection: String, CaseIterable, Identifiable {
    case japanese
    case standard

    var id: String {
        rawValue
    }
}

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings

    @AppStorage("readerViewMode")
    private var readerViewModeRawValue = ReaderViewMode.basicSlide.rawValue

    @AppStorage("bookReadingDirection")
    private var bookReadingDirectionRawValue = BookReadingDirection.japanese.rawValue

    var body: some View {
        Form {
            languageSection
            readerSection
        }
        .navigationTitle(settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            Picker(languagePickerTitle, selection: $settings.galleryLanguage) {
                ForEach(GalleryLanguage.allCases) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
        } header: {
            Text(languageSectionTitle)
        } footer: {
            Text(languageDescription)
        }
    }

    // MARK: - Reader

    private var readerSection: some View {
        Section {
            Picker(
                readerViewModeTitle,
                selection: $readerViewModeRawValue
            ) {
                ForEach(ReaderViewMode.allCases) { mode in
                    Text(readerViewModeName(mode))
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.navigationLink)

            if selectedReaderViewMode == .book {
                Picker(
                    bookReadingDirectionTitle,
                    selection: $bookReadingDirectionRawValue
                ) {
                    ForEach(BookReadingDirection.allCases) { direction in
                        Text(bookReadingDirectionName(direction))
                            .tag(direction.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Picker(
                readerLoadingModeTitle,
                selection: $settings.preloadAllReaderImages
            ) {
                Text(dataSavingModeTitle)
                    .tag(false)

                Text(smoothModeTitle)
                    .tag(true)
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text(readerSettingsTitle)
        } footer: {
            Text(readerSectionDescription)
        }
    }

    private var selectedReaderViewMode: ReaderViewMode {
        ReaderViewMode(
            rawValue: readerViewModeRawValue
        ) ?? .basicSlide
    }

    // MARK: - Settings Localization

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

    // MARK: - Language Localization

    private var languageSectionTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "언어"
        case .english:
            return "Language"
        case .japanese:
            return "言語"
        }
    }

    private var languagePickerTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "작품 언어"
        case .english:
            return "Gallery Language"
        case .japanese:
            return "作品の言語"
        }
    }

    private var languageDescription: String {
        switch settings.galleryLanguage {
        case .korean:
            return "목록에 표시할 작품의 언어를 선택합니다."
        case .english:
            return "Choose the language of galleries shown in the list."
        case .japanese:
            return "一覧に表示する作品の言語を選択します。"
        }
    }

    // MARK: - Reader Localization

    private var readerSettingsTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "리더"
        case .english:
            return "Reader"
        case .japanese:
            return "リーダー"
        }
    }

    // Readerの表示方式
    private var readerViewModeTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "보기 방식"
        case .english:
            return "View Mode"
        case .japanese:
            return "表示方式"
        }
    }

    // 表示方式ごとの表示名
    private func readerViewModeName(
        _ mode: ReaderViewMode
    ) -> String {
        switch mode {
        case .basicSlide:
            switch settings.galleryLanguage {
            case .korean:
                return "기본 슬라이드"
            case .english:
                return "Basic Slide"
            case .japanese:
                return "基本スライド"
            }

        case .book:
            switch settings.galleryLanguage {
            case .korean:
                return "책읽기 모드"
            case .english:
                return "Book Reading"
            case .japanese:
                return "本読みモード"
            }
        }
    }

    // 本読みモードで使用するページ送り方向
    private var bookReadingDirectionTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "페이지 넘김 방식"
        case .english:
            return "Page Direction"
        case .japanese:
            return "ページ送り方式"
        }
    }

    // ページ送り方向ごとの表示名
    private func bookReadingDirectionName(
        _ direction: BookReadingDirection
    ) -> String {
        switch direction {
        case .japanese:
            switch settings.galleryLanguage {
            case .korean:
                return "일본식"
            case .english:
                return "Japanese"
            case .japanese:
                return "日本式"
            }

        case .standard:
            switch settings.galleryLanguage {
            case .korean:
                return "기본"
            case .english:
                return "Standard"
            case .japanese:
                return "標準"
            }
        }
    }

    // Readerの画像読み込み方式
    private var readerLoadingModeTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "이미지 불러오기"
        case .english:
            return "Image Loading"
        case .japanese:
            return "画像の読み込み"
        }
    }

    // データ通信量を抑えるモード
    private var dataSavingModeTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "데이터 절약 모드"
        case .english:
            return "Data Saving Mode"
        case .japanese:
            return "データ節約モード"
        }
    }

    // 全ページを事前に読み込むモード
    private var smoothModeTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "쾌적 모드"
        case .english:
            return "Smooth Reading Mode"
        case .japanese:
            return "快適モード"
        }
    }

    // Reader設定全体について説明する
    private var readerSectionDescription: String {
        "\(readerViewModeDescription)\n\n\(readerLoadingModeDescription)"
    }

    // 表示方式と本読みモードの操作方法について説明する
    private var readerViewModeDescription: String {
        switch settings.galleryLanguage {
        case .korean:
            if selectedReaderViewMode == .book {
                return "책읽기 모드는 한 페이지씩 표시합니다. 일본식은 왼쪽 탭 또는 오른쪽 스와이프로 다음 페이지로 이동하고, 기본은 반대 방향입니다."
            }

            return "기본 슬라이드는 기존처럼 위아래로 스크롤하며 읽습니다."

        case .english:
            if selectedReaderViewMode == .book {
                return "Book Reading shows one page at a time. Japanese advances with a left tap or right swipe; Standard uses the opposite direction."
            }

            return "Basic Slide uses the existing vertical scrolling reader."

        case .japanese:
            if selectedReaderViewMode == .book {
                return "本読みモードは1ページずつ表示します。日本式は左側のタップまたは右スワイプで次のページへ進み、標準は逆方向です。"
            }

            return "基本スライドは従来どおり上下にスクロールして読み進めます。"
        }
    }

    // Readerの読み込み方式について説明する
    private var readerLoadingModeDescription: String {
        switch settings.galleryLanguage {
        case .korean:
            return "데이터 절약 모드는 필요한 이미지만 불러옵니다. 쾌적 모드는 모든 이미지를 백그라운드에서 미리 불러와 보다 부드럽게 감상할 수 있습니다."

        case .english:
            return "Data Saving Mode loads only the images you need. Smooth Reading Mode preloads all images in the background for smoother reading."

        case .japanese:
            return "データ節約モードは必要な画像だけを読み込みます。快適モードはすべての画像をバックグラウンドで事前に読み込み、よりスムーズに閲覧できます。"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppSettings())
    }
}
