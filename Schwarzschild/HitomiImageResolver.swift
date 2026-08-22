import Foundation

actor HitomiImageResolver {

    enum ResolverError: LocalizedError {
        case invalidGGURL
        case invalidGGResponse
        case invalidBasePath
        case invalidMFunction
        case invalidMDefault
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
            case .invalidMFunction:
                return "gg.m() の解析に失敗しました。"
            case .invalidMDefault:
                return "gg.m() のデフォルト値を取得できませんでした。"
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

    // gg.m(g) の switch 文に明示されている値を保持する
    // Key: gg.s(hash) の値
    // Value: gg.m(g) が返す 0 または 1
    private var ggMap: [Int: Int] = [:]

    // switch に該当しない場合に gg.m(g) が返す初期値
    private var ggDefaultValue = 0

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
                value: String(Int(Date().timeIntervalSince1970))
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

        let mFunction = try parseMFunction(
            from: script
        )

        let parsedDefaultValue = try parseMDefaultValue(
            from: mFunction
        )

        let parsedGGMap = parseGGMap(
            from: mFunction
        )

        basePath = parsedBasePath
        ggDefaultValue = parsedDefaultValue
        ggMap = parsedGGMap
        initialized = true

        print(
            "[Resolver] gg.js loaded:",
            "b=\(parsedBasePath)",
            "defaultM=\(parsedDefaultValue)",
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

        // switch に明示された値があればそれを使い、
        // それ以外は gg.m() の初期値を使用する
        let mappedValue = ggMap[g]
        let m = mappedValue ?? ggDefaultValue

        print(
            "[Resolver] URL:",
            "g=\(g)",
            "m=\(m)",
            mappedValue == nil ? "source=default" : "source=case"
        )

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

        return String(script[captureRange])
    }

    // gg.m(g) の関数本体だけを取り出す
    private func parseMFunction(
        from script: String
    ) throws -> String {
        let pattern =
            #"(?s)m\s*:\s*function\s*\(\s*g\s*\)\s*\{(.*?)return\s+o\s*;"#

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
            throw ResolverError.invalidMFunction
        }

        return String(script[captureRange])
    }

    // gg.m(g) の switch に入る前の o の初期値を取得する
    private func parseMDefaultValue(
        from functionBody: String
    ) throws -> Int {
        let pattern =
            #"(?:var|let|const)\s+o\s*=\s*([01])\s*;"#

        let regex = try NSRegularExpression(
            pattern: pattern
        )

        let range = NSRange(
            functionBody.startIndex..<functionBody.endIndex,
            in: functionBody
        )

        guard
            let match = regex.firstMatch(
                in: functionBody,
                range: range
            ),
            let captureRange = Range(
                match.range(at: 1),
                in: functionBody
            ),
            let value = Int(functionBody[captureRange])
        else {
            throw ResolverError.invalidMDefault
        }

        return value
    }

    // gg.m(g) の switch 文を解析して case -> o の対応表を作る
    private func parseGGMap(
        from functionBody: String
    ) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var pendingCases: [Int] = []

        let tokenPattern =
            #"case\s+(\d+)\s*:|\bo\s*=\s*([01])\s*;"#

        guard let regex = try? NSRegularExpression(
            pattern: tokenPattern
        ) else {
            return result
        }

        let fullRange = NSRange(
            functionBody.startIndex..<functionBody.endIndex,
            in: functionBody
        )

        let matches = regex.matches(
            in: functionBody,
            range: fullRange
        )

        for match in matches {
            // case 数値:
            if
                match.range(at: 1).location != NSNotFound,
                let range = Range(
                    match.range(at: 1),
                    in: functionBody
                ),
                let value = Int(functionBody[range])
            {
                pendingCases.append(value)
                continue
            }

            // o = 0; または o = 1;
            if
                match.range(at: 2).location != NSNotFound,
                let range = Range(
                    match.range(at: 2),
                    in: functionBody
                ),
                let value = Int(functionBody[range]),
                !pendingCases.isEmpty
            {
                for caseValue in pendingCases {
                    result[caseValue] = value
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

        let suffix = String(hash.suffix(3))
        let firstTwo = String(suffix.prefix(2))
        let lastOne = String(suffix.suffix(1))
        let reordered = lastOne + firstTwo

        guard let value = Int(
            reordered,
            radix: 16
        ) else {
            throw ResolverError.invalidHash
        }

        return value
    }
}
