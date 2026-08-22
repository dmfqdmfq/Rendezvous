import Foundation

actor ReaderImageCache {

    enum CacheError: LocalizedError {
        case invalidHTTPResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                return "HTTPレスポンスを取得できませんでした。"
            case .httpError(let statusCode):
                return "画像の取得に失敗しました。HTTP \(statusCode)"
            }
        }
    }

    private var storage: [String: Data] = [:]
    private var inFlight: [String: Task<Data, Error>] = [:]

    // キャッシュ済みの画像データを取得する
    func data(for hash: String) -> Data? {
        storage[hash]
    }

    // 指定した画像がキャッシュ済みか確認する
    func contains(_ hash: String) -> Bool {
        storage[hash] != nil
    }

    // 画像データをキャッシュに保存する
    func store(_ data: Data, for hash: String) {
        storage[hash] = data
    }

    // 同じ画像の重複ダウンロードを防ぎながらデータを取得する
    func loadData(for hash: String, request: URLRequest) async throws -> Data {
        if let cachedData = storage[hash] {
            return cachedData
        }

        if let runningTask = inFlight[hash] {
            return try await runningTask.value
        }

        let task = Task<Data, Error> {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CacheError.invalidHTTPResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw CacheError.httpError(httpResponse.statusCode)
            }

            return data
        }

        inFlight[hash] = task

        do {
            let data = try await task.value
            storage[hash] = data
            inFlight[hash] = nil
            return data
        } catch {
            inFlight[hash] = nil
            throw error
        }
    }

    // Readerを閉じたときに進行中の通信を停止する
    func cancelAllInFlight() {
        for task in inFlight.values {
            task.cancel()
        }

        inFlight.removeAll()
    }

    // キャッシュをすべて削除する
    func removeAll() {
        storage.removeAll()
    }
}
