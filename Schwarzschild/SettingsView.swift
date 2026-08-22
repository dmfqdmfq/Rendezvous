import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings

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
            Text(readerLoadingModeDescription)
        }
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
