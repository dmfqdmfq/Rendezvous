import Foundation
import SwiftUI
import Combine

// MARK: - Gallery Language

enum GalleryLanguage: String, CaseIterable, Identifiable {

    case english
    case japanese
    case korean

    var id: String {
        rawValue
    }

    // 設定画面に表示する言語名
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"

        }
    }

    // アプリ内に表示するタイトル
    var appTitle: String {
        switch self {
        case .japanese:
            return "ランデブー"

        case .korean, .english:
            return "Rendezvous"
        }
    }

    // Readerへ移動するボタンの表示名
    var readButtonTitle: String {
        switch self {

        case .english:
            return "Read"

        case .japanese:
            return "読む"
            
        case .korean:
            return "읽기"
        }
    }
    
}

// MARK: - Reader設定

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

// MARK: - App Settings

@MainActor
final class AppSettings: ObservableObject {

    
    private enum Keys {
        static let galleryLanguage = "galleryLanguage"
    }

    // Readerで全ページを事前に読み込むかどうか
    @Published var preloadAllReaderImages: Bool {
        didSet {
            UserDefaults.standard.set(
                preloadAllReaderImages,
                forKey: "preloadAllReaderImages"
            )
        }
    }
    // ギャラリー言語の設定を保持する
    @Published var galleryLanguage: GalleryLanguage {
        didSet {
            UserDefaults.standard.set(
                galleryLanguage.rawValue,
                forKey: Keys.galleryLanguage
            )
        }
    }

    init() {
        preloadAllReaderImages = UserDefaults.standard.bool(
                forKey: "preloadAllReaderImages"
            )
        // 保存済みの言語設定がある場合は、その設定を優先する
        if let storedValue = UserDefaults.standard.string(
            forKey: Keys.galleryLanguage
        ),
        let language = GalleryLanguage(rawValue: storedValue) {

            galleryLanguage = language
            return
        }

        // 保存済みの設定がない場合は、iPhoneの優先言語から初期値を決定する
        let preferredLanguage =
            Locale.preferredLanguages.first ?? "en"

        if preferredLanguage.hasPrefix("ja") {
            // iPhoneが日本語の場合
            galleryLanguage = .japanese
        } else if preferredLanguage.hasPrefix("ko") {
            // iPhoneが韓国語の場合
            galleryLanguage = .korean
        } else {
            // その他の言語の場合は英語を使用する
            galleryLanguage = .english
        }
    }
}
