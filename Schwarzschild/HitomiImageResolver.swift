import Foundation

actor HitomiImageResolver {

    private let ggURL = URL(
        string: "https://ltn.gold-usergeneratedcontent.net/gg.js"
    )!

    private let imageDomain = "gold-usergeneratedcontent.net"

    private var ggB: String?
    private var ggCases: Set<Int> = []

    // MARK: - 初期化
    // 最新の gg.js を取得し、画像URL生成に必要な情報を読み込む
    func initialize() async throws {
        let (data, response) = try await URLSession.shared.data(
            from: ggURL
        )

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ResolverError.invalidResponse
        }

        guard let text = String(
            data: data,
            encoding: .utf8
        ) else {
            throw ResolverError.invalidGGScript
        }

        guard let b = extractB(from: text) else {
            throw ResolverError.ggBNotFound
        }

        let cases = extractCases(from: text)

        guard !cases.isEmpty else {
            throw ResolverError.ggCasesNotFound
        }

        ggB = b
        ggCases = cases
    }

    // MARK: - URL生成

    // ファイルハッシュからAVIF画像のURLを生成する
    func imageURL(for hash: String) throws -> URL {
        guard let ggB else {
            throw ResolverError.notInitialized
        }

        guard let g = ggS(hash) else {
            throw ResolverError.invalidHash
        }

        // JavaScript の gg.m(g) を再現する
        let m = ggCases.contains(g) ? 1 : 0

        // CDNサブドメインは a1 または a2 になる
        let subdomain = "a\(1 + m)"

        let urlString =
            "https://\(subdomain).\(imageDomain)/" +
            "\(ggB)\(g)/\(hash).avif"

        guard let url = URL(string: urlString) else {
            throw ResolverError.invalidURL
        }

        return url
    }

    // 画像CDNへのアクセスに必要なRefererを含むURLRequestを生成する
    func imageRequest(for hash: String) throws -> URLRequest {
        let url = try imageURL(for: hash)

        var request = URLRequest(url: url)

        request.setValue(
            "https://hitomi.la/",
            forHTTPHeaderField: "Referer"
        )

        return request
    }

    // MARK: - gg.js解析

    // gg.js から gg.b の値を取得する
    private func extractB(from text: String) -> String? {
        let pattern = #"b:\s*'([^']+)'"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let searchRange = NSRange(
            text.startIndex...,
            in: text
        )

        guard let match = regex.firstMatch(
            in: text,
            range: searchRange
        ) else {
            return nil
        }

        guard let range = Range(
            match.range(at: 1),
            in: text
        ) else {
            return nil
        }

        return String(text[range])
    }

    // gg.m() の switch 文に含まれる case 値を取得する
    private func extractCases(from text: String) -> Set<Int> {
        let pattern = #"case\s+(\d+):"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return []
        }

        let matches = regex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )

        let values = matches.compactMap { match -> Int? in
            guard let range = Range(
                match.range(at: 1),
                in: text
            ) else {
                return nil
            }

            return Int(String(text[range]))
        }

        return Set(values)
    }

    // JavaScript の gg.s(hash) を Swift で再現する
    private func ggS(_ hash: String) -> Int? {
        guard hash.count >= 3 else {
            return nil
        }

        let last3 = Array(hash.suffix(3))

        // 例: "7b3" → "37b"
        let reordered =
            "\(last3[2])\(last3[0])\(last3[1])"

        // 並べ替えた値を16進数として解釈する
        return Int(reordered, radix: 16)
    }
}

// MARK: - Error

enum ResolverError: Error {
    case invalidResponse
    case invalidGGScript
    case ggBNotFound
    case ggCasesNotFound
    case notInitialized
    case invalidHash
    case invalidURL
}
