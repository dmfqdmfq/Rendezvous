import Foundation

// MARK: - Models

struct GalleryInfo: Decodable, Identifiable {
    let id: String
    let title: String
    let language: String?
    let languageLocalname: String?
    let files: [GalleryFile]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case language
        case languageLocalname = "language_localname"
        case files
    }
}

struct GalleryFile: Decodable {
    let name: String
    let width: Int
    let height: Int
    let hash: String
    let hasAVIF: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case width
        case height
        case hash
        case hasAVIF = "hasavif"
    }
}

// MARK: - Service

struct HitomiGalleryService {

    private let baseURL =
        "https://ltn.gold-usergeneratedcontent.net/galleries"


    // ギャラリーIDから作品情報を取得する
    func fetchGallery(id: String) async throws -> GalleryInfo {

        let urlString = "\(baseURL)/\(id).js"

        guard let url = URL(string: urlString) else {
            throw GalleryServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GalleryServiceError.invalidResponse
        }

        guard var text = String(
            data: data,
            encoding: .utf8
        ) else {
            throw GalleryServiceError.invalidEncoding
        }

        // JavaScriptの変数宣言を削除し、JSON部分だけを取り出す
        let prefix = "var galleryinfo = "

        guard text.hasPrefix(prefix) else {
            throw GalleryServiceError.invalidFormat
        }

        text.removeFirst(prefix.count)

        // 末尾にセミコロンがある場合は削除する
        if text.hasSuffix(";") {
            text.removeLast()
        }

        guard let jsonData = text.data(using: .utf8) else {
            throw GalleryServiceError.invalidEncoding
        }

        return try JSONDecoder().decode(
            GalleryInfo.self,
            from: jsonData
        )
    }
}

// MARK: - Error

enum GalleryServiceError: Error {
    case invalidURL
    case invalidResponse
    case invalidEncoding
    case invalidFormat
}
