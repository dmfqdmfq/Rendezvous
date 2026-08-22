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
            
            Section {
                Toggle(
                    preloadImagesTitle,
                    isOn: $settings.preloadAllReaderImages
                )
            } header: {
                Text(readerSettingsTitle)
            } footer: {
                Text(preloadImagesDescription)
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
    
    // Reader設定のセクション名
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
    
    // 全ページ事前読み込み設定の表示名
    // Readerの読み込み方式の表示名
    private var preloadImagesTitle: String {
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
    private var preloadImagesDescription: String {
        switch settings.galleryLanguage {
        case .korean:
            return """
            켜면 작품의 모든 이미지를 백그라운드에서 미리 불러와 보다 쾌적하게 감상할 수 있습니다. \
            끄면 현재 필요한 이미지만 불러와 데이터 사용량을 줄입니다.
            """

        case .english:
            return """
            When enabled, all images are preloaded in the background for smoother reading. \
            When disabled, only the images you need are loaded to reduce data usage.
            """

        case .japanese:
            return """
            オンにすると、すべての画像をバックグラウンドで事前に読み込み、より快適に閲覧できます。\
            オフにすると、必要な画像だけを読み込み、データ通信量を抑えます。
            """
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppSettings())
    }
}
