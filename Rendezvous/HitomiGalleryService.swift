import Foundation

// MARK: - Models

nonisolated struct GalleryInfo: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let language: String?
    let languageLocalname: String?
    let tags: [GalleryTag]?
    let files: [GalleryFile]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case language
        case languageLocalname = "language_localname"
        case tags
        case files
    }
}

// MARK: - ギャラリータグ

nonisolated struct GalleryTag: Codable, Sendable {
    nonisolated enum Category: Sendable {
        case male
        case female
        case other
    }

    let name: String
    private let male: String?
    private let female: String?

    var category: Category {
        if male == "1" {
            return .male
        }

        if female == "1" {
            return .female
        }

        return .other
    }

    var displayName: String {
        switch category {
        case .male:
            return "male:\(name)"
        case .female:
            return "female:\(name)"
        case .other:
            return name
        }
    }

    enum CodingKeys: String, CodingKey {
        case name = "tag"
        case male
        case female
    }
}

nonisolated struct GalleryFile: Codable, Sendable {
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

nonisolated struct HitomiGalleryService {

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

nonisolated enum GalleryServiceError: Error {
    case invalidURL
    case invalidResponse
    case invalidEncoding
    case invalidFormat
}
