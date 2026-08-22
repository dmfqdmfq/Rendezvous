import Foundation

actor HitomiImageResolver {

    enum ResolverError: LocalizedError {
        case invalidGGURL
        case invalidGGResponse
        case invalidBasePath
        case invalidHash
        case invalidImageURL

        var errorDescription: String? {
            switch self {
            case .invalidGGURL:
                return "gg.js のURLを生成できませんでした。"
            case .invalidGGResponse:
                return "gg.js の取得または解析に失敗しました。"
            case .invalidBasePath:
                return "gg.js からベースパスを取得できませんでした。"
            case .invalidHash:
                return "画像ハッシュの形式が不正です。"
            case .invalidImageURL:
                return "画像URLを生成できませんでした。"
            }
        }
    }


    // MARK: - Properties

    private let ggURLString =
        "https://ltn.gold-usergeneratedcontent.net/gg.js"

    private let imageDomain =
        "gold-usergeneratedcontent.net"

    private var basePath: String?

    // gg.m(g) の switch 文を解析した結果を保持する
    // Key: gg.s(hash) の値
    // Value: gg.m(g) が返す 0 または 1
    private var ggMap: [Int: Int] = [:]

    private var initialized = false


    // MARK: - Initialization

    // 最新の gg.js を取得してURL生成ルールを準備する
    func initialize() async throws {
        if initialized {
            return
        }

        try await reloadGG()
    }


    // gg.js を強制的に再取得して解析する
    func reloadGG() async throws {
        guard var components = URLComponents(
            string: ggURLString
        ) else {
            throw ResolverError.invalidGGURL
        }

        // CDNやURLSessionのキャッシュを避けるため毎回異なるクエリを付与する
        components.queryItems = [
            URLQueryItem(
                name: "_",
                value: String(
                    Int(Date().timeIntervalSince1970)
                )
            )
        ]

        guard let url = components.url else {
            throw ResolverError.invalidGGURL
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        request.setValue(
            "https://hitomi.la/",
            forHTTPHeaderField: "Referer"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let script = String(
                data: data,
                encoding: .utf8
            )
        else {
            throw ResolverError.invalidGGResponse
        }

        let parsedBasePath = try parseBasePath(
            from: script
        )

        let parsedGGMap = parseGGMap(
            from: script
        )

        basePath = parsedBasePath
        ggMap = parsedGGMap
        initialized = true

        print(
            "[Resolver] gg.js loaded:",
            "b=\(parsedBasePath)",
            "mappedCases=\(parsedGGMap.count)"
        )
    }


    // MARK: - Public API

    // 画像ハッシュからAVIF画像のURLRequestを生成する
    func imageRequest(
        for hash: String
    ) async throws -> URLRequest {
        if !initialized {
            try await initialize()
        }

        let url = try imageURL(
            for: hash,
            fileExtension: "avif"
        )

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        // 画像CDNはRefererを確認するため必ず付与する
        request.setValue(
            "https://hitomi.la/",
            forHTTPHeaderField: "Referer"
        )

        return request
    }


    // 必要に応じて拡張子を指定して画像URLを生成する
    func imageURL(
        for hash: String,
        fileExtension: String = "avif"
    ) throws -> URL {
        guard let basePath else {
            throw ResolverError.invalidBasePath
        }

        let g = try ggS(hash)

        // gg.m(g) は case の存在有無ではなく、
        // 各 case グループの最終的な o = 0 / o = 1 を返す
        let m = ggMap[g] ?? 0

        let subdomain = 1 + m

        let urlString =
            "https://a\(subdomain).\(imageDomain)/" +
            "\(basePath)\(g)/\(hash).\(fileExtension)"

        guard let url = URL(
            string: urlString
        ) else {
            throw ResolverError.invalidImageURL
        }

        return url
    }


    // MARK: - gg.js Parsing

    // gg.b の値を取得する
    private func parseBasePath(
        from script: String
    ) throws -> String {
        let pattern = #"b:\s*'([^']+)'"#

        let regex = try NSRegularExpression(
            pattern: pattern
        )

        let range = NSRange(
            script.startIndex..<script.endIndex,
            in: script
        )

        guard
            let match = regex.firstMatch(
                in: script,
                range: range
            ),
            let captureRange = Range(
                match.range(at: 1),
                in: script
            )
        else {
            throw ResolverError.invalidBasePath
        }

        return String(
            script[captureRange]
        )
    }


    // gg.m(g) の switch 文を解析して case -> o の対応表を作る
    private func parseGGMap(
        from script: String
    ) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var pendingCases: [Int] = []

        let caseRegex = try? NSRegularExpression(
            pattern: #"case\s+(\d+)\s*:"#
        )

        let assignmentRegex = try? NSRegularExpression(
            pattern: #"\bo\s*=\s*([01])\s*;"#
        )

        for rawLine in script.components(
            separatedBy: .newlines
        ) {
            let line = rawLine as NSString
            let fullRange = NSRange(
                location: 0,
                length: line.length
            )

            if
                let caseRegex,
                let match = caseRegex.firstMatch(
                    in: rawLine,
                    range: fullRange
                ),
                match.numberOfRanges >= 2
            {
                let valueString = line.substring(
                    with: match.range(at: 1)
                )

                if let value = Int(valueString) {
                    pendingCases.append(value)
                }
            }

            if
                !pendingCases.isEmpty,
                let assignmentRegex,
                let match = assignmentRegex.firstMatch(
                    in: rawLine,
                    range: fullRange
                ),
                match.numberOfRanges >= 2
            {
                let resultString = line.substring(
                    with: match.range(at: 1)
                )

                if let value = Int(resultString) {
                    for caseValue in pendingCases {
                        result[caseValue] = value
                    }
                }

                pendingCases.removeAll(
                    keepingCapacity: true
                )
            }
        }

        return result
    }


    // gg.s(hash) と同じ変換をSwiftで再現する
    private func ggS(
        _ hash: String
    ) throws -> Int {
        guard hash.count >= 3 else {
            throw ResolverError.invalidHash
        }

        let suffix = String(
            hash.suffix(3)
        )

        let firstTwo = String(
            suffix.prefix(2)
        )

        let lastOne = String(
            suffix.suffix(1)
        )

        let reordered =
            lastOne + firstTwo

        guard let value = Int(
            reordered,
            radix: 16
        ) else {
            throw ResolverError.invalidHash
        }

        return value
    }
}
