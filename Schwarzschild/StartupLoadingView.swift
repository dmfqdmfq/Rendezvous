import SwiftUI

struct StartupLoadingView: View {

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            // アプリ名を現在の言語設定に合わせて表示する
            Text(settings.galleryLanguage.appTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .controlSize(.large)

            Text(loadingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    // MARK: - Localized Text

    // 起動時の読み込みメッセージ
    private var loadingText: String {
        switch settings.galleryLanguage {
        case .korean:
            return "불러오는 중..."

        case .english:
            return "Loading..."

        case .japanese:
            return "読み込み中..."
        }
    }
}

#Preview {
    StartupLoadingView()
        .environmentObject(AppSettings())
}
