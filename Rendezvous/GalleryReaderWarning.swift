import Foundation

struct GalleryReaderWarning {
    static let pageThreshold = 100
    static let veryLargePageThreshold = 1000

    let pageCount: Int
    let language: GalleryLanguage
    let preloadAllImages: Bool

    var title: String {
        let isVeryLarge = pageCount >= Self.veryLargePageThreshold

        switch language {
        case .english:
            return isVeryLarge ? "Very Large Gallery" : "Mobile Data Warning"
        case .japanese:
            return isVeryLarge ? "非常に大きな作品です" : "モバイルデータ通信に注意"
        case .korean:
            return isVeryLarge ? "매우 큰 작품입니다" : "모바일 데이터 사용 주의"
        }
    }

    var message: String {
        let isVeryLarge = pageCount >= Self.veryLargePageThreshold

        switch language {
        case .english:
            if isVeryLarge {
                return """
                This gallery has \(pageCount) pages. Mobile data usage may be very high. Wi‑Fi is recommended when possible.
                """
            }

            if preloadAllImages {
                return """
                This gallery has \(pageCount) pages. Smooth Reading Mode is enabled, so all images will be preloaded in the background and may use a significant amount of mobile data.
                """
            }

            return """
            This gallery has \(pageCount) pages. Reading it over a cellular connection may use a significant amount of mobile data.
            """

        case .japanese:
            if isVeryLarge {
                return """
                この作品は\(pageCount)ページあります。モバイルデータ通信量が非常に多くなる可能性があります。可能であればWi‑Fi環境での利用をおすすめします。
                """
            }

            if preloadAllImages {
                return """
                この作品は\(pageCount)ページあります。現在は快適モードが有効なため、すべての画像をバックグラウンドで事前に読み込みます。モバイルデータ通信量が多くなる可能性があります。
                """
            }

            return """
            この作品は\(pageCount)ページあります。モバイル通信で閲覧すると、データ通信量が多くなる可能性があります。
            """

        case .korean:
            if isVeryLarge {
                return """
                이 작품은 \(pageCount)페이지입니다. 모바일 데이터 사용량이 매우 많을 수 있습니다. 가능하면 Wi‑Fi 환경에서 이용하는 것을 권장합니다.
                """
            }

            if preloadAllImages {
                return """
                이 작품은 \(pageCount)페이지입니다. 현재 쾌적 모드가 켜져 있어 모든 이미지를 백그라운드에서 미리 불러옵니다. 모바일 데이터를 많이 사용할 수 있습니다.
                """
            }

            return """
            이 작품은 \(pageCount)페이지입니다. 모바일 데이터로 읽을 경우 데이터 사용량이 많아질 수 있습니다.
            """
        }
    }

    var cancelTitle: String {
        switch language {
        case .english:
            return "Cancel"
        case .japanese:
            return "キャンセル"
        case .korean:
            return "취소"
        }
    }

    var continueTitle: String {
        switch language {
        case .english:
            return "Continue"
        case .japanese:
            return "続けて読む"
        case .korean:
            return "계속 읽기"
        }
    }
}
