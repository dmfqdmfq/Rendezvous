import SwiftUI


struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {

            Section {
                Picker(
                    languagePickerTitle,
                    selection: $settings.galleryLanguage
                ) {
                    ForEach(GalleryLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
            } header: {
                Text(languageSectionTitle)
            } footer: {
                Text(languageFooterText)
            }
        }
        .navigationTitle(settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Localized Text

    // 設定画面のタイトル
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

    // 言語設定セクションのタイトル
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

    // 言語選択項目のタイトル
    private var languagePickerTitle: String {
        switch settings.galleryLanguage {
        case .korean:
            return "작품 언어"

        case .english:
            return "Content Language"

        case .japanese:
            return "作品の言語"
        }
    }

    // 言語設定についての説明
    private var languageFooterText: String {
        switch settings.galleryLanguage {
        case .korean:
            return "선택한 언어의 작품이 메인 화면에 표시됩니다."

        case .english:
            return "The main screen displays works in the selected language."

        case .japanese:
            return "選択した言語の作品がメイン画面に表示されます。"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppSettings())
    }
}
