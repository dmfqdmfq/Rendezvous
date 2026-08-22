import Foundation
import Combine

@MainActor
final class GalleryListViewModel: ObservableObject {

    @Published private(set) var galleries: [GalleryInfo] = []
    // 初回起動時は読み込み状態から開始する
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let indexService = HitomiIndexService()
    private let galleryService = HitomiGalleryService()

    // 最新の読み込み要求を識別するためのID
    private var currentLoadID = UUID()


    // 指定した言語とページのギャラリー一覧を取得する
    func load(
        language: GalleryLanguage,
        page: Int = 1
    ) async {

        // 新しい読み込み要求ごとに固有のIDを発行する
        let loadID = UUID()
        currentLoadID = loadID

        isLoading = true
        errorMessage = nil

        do {
            // 指定された言語のnozomiインデックスからIDを取得する
            let ids = try await indexService.fetchGalleryIDs(
                language: language,
                page: page
            )

            var loadedGalleries: [GalleryInfo] = []

            // 各ギャラリーの詳細情報を取得する
            for id in ids {

                // より新しい読み込み要求が開始された場合は処理を中止する
                guard loadID == currentLoadID else {
                    return
                }

                do {
                    let gallery = try await galleryService.fetchGallery(
                        id: String(id)
                    )

                    loadedGalleries.append(gallery)

                } catch {
                    // 1件の取得失敗で一覧全体を失敗させない
                    print(
                        "Gallery \(id) load failed:",
                        error
                    )
                }
            }

            // この要求がまだ最新の場合のみ画面へ反映する
            guard loadID == currentLoadID else {
                return
            }

            galleries = loadedGalleries
            isLoading = false

        } catch {

            // 古い要求のエラーは画面に反映しない
            guard loadID == currentLoadID else {
                return
            }

            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
