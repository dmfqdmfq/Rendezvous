import Foundation

struct HitomiIndexService {
    // 指定した言語とページからギャラリーID一覧を取得する
    // 1ページあたり25件、1件あたり4バイト
    func fetchGalleryIDs(
        language: GalleryLanguage,
        page: Int = 1
    ) async throws -> [Int] {

        guard page >= 1 else {
            throw HitomiIndexError.invalidPage
        }

        let urlString =
            "https://ltn.gold-usergeneratedcontent.net/" +
            "index-\(language.rawValue).nozomi"

        guard let indexURL = URL(string: urlString) else {
            throw HitomiIndexError.invalidURL
        }

        // 25件 × 4バイト = 100バイト
        let startByte = (page - 1) * 100
        let endByte = startByte + 99

        var request = URLRequest(url: indexURL)

        // nozomiファイルの必要な範囲だけを取得する
        request.setValue(
            "bytes=\(startByte)-\(endByte)",
            forHTTPHeaderField: "Range"
        )

        // バイト範囲をそのまま扱うため圧縮を無効化する
        request.setValue(
            "identity",
            forHTTPHeaderField: "Accept-Encoding"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 206 else {
            throw HitomiIndexError.invalidResponse
        }

        guard data.count % 4 == 0 else {
            throw HitomiIndexError.invalidData
        }

        var galleryIDs: [Int] = []

        // 各IDは4バイトのBig Endian整数として保存されている
        for offset in stride(
            from: 0,
            to: data.count,
            by: 4
        ) {
            let bytes = data[offset..<(offset + 4)]

            let value = bytes.reduce(UInt32(0)) {
                ($0 << 8) | UInt32($1)
            }

            galleryIDs.append(Int(value))
        }

        return galleryIDs
    }
}

enum HitomiIndexError: Error {
    case invalidURL
    case invalidPage
    case invalidResponse
    case invalidData
}
