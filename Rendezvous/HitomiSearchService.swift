import Foundation
import CryptoKit

nonisolated struct HitomiTagSuggestion: Identifiable, Hashable, Sendable {
    nonisolated enum Namespace: String, Sendable {
        case male
        case female
        case tag
    }

    let name: String
    let count: Int?
    let namespace: Namespace

    var id: String {
        "\(namespace.rawValue):\(name)"
    }

    var queryToken: String {
        let encodedName = name.replacingOccurrences(of: " ", with: "_")
        return "\(namespace.rawValue):\(encodedName)"
    }

    init(name: String, count: Int?, namespace: Namespace) {
        self.name = name
        self.count = count
        self.namespace = namespace
    }

    init(tag: GalleryTag) {
        name = tag.name
        count = nil

        switch tag.category {
        case .male:
            namespace = .male
        case .female:
            namespace = .female
        case .other:
            namespace = .tag
        }
    }
}

// MARK: - タグ候補

actor HitomiTagSuggestionService {
    private let domain = "tagindex.hitomi.la"
    private var cache: [String: [HitomiTagSuggestion]] = [:]

    func suggestions(for token: String) async throws -> [HitomiTagSuggestion] {
        let normalizedToken = token.lowercased()

        if let cached = cache[normalizedToken] {
            return cached
        }

        let (field, term) = suggestionFieldAndTerm(for: normalizedToken)
        let pathComponents = term.map(encodePathCharacter)

        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/" + ([field] + pathComponents).joined(separator: "/") + ".json"

        guard let url = components.url else {
            throw HitomiSearchError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw HitomiSearchError.invalidResponse
        }

        let rawSuggestions = try JSONDecoder().decode(
            [RawTagSuggestion].self,
            from: data
        )
        let suggestions: [HitomiTagSuggestion] = rawSuggestions.compactMap {
            suggestion -> HitomiTagSuggestion? in
            guard let namespace = HitomiTagSuggestion.Namespace(
                rawValue: suggestion.namespace
            ) else {
                return nil
            }

            return HitomiTagSuggestion(
                name: suggestion.name,
                count: suggestion.count,
                namespace: namespace
            )
        }

        let limitedSuggestions = Array(suggestions.prefix(30))
        cache[normalizedToken] = limitedSuggestions
        return limitedSuggestions
    }

    private func suggestionFieldAndTerm(for token: String) -> (String, String) {
        guard let separatorIndex = token.firstIndex(of: ":") else {
            return ("global", token)
        }

        let field = String(token[..<separatorIndex])
        let termStart = token.index(after: separatorIndex)
        let term = String(token[termStart...])

        if HitomiTagSuggestion.Namespace(rawValue: field) != nil {
            return (field, term)
        }

        return ("global", term)
    }

    private func encodePathCharacter(_ character: Character) -> String {
        switch character {
        case " ":
            return "_"
        case "/":
            return "slash"
        case ".":
            return "dot"
        default:
            return String(character)
        }
    }
}

nonisolated private struct RawTagSuggestion: Decodable {
    let name: String
    let count: Int
    let namespace: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name = try container.decode(String.self)
        count = try container.decode(Int.self)
        namespace = try container.decode(String.self)
    }
}

// MARK: - 作品検索

actor HitomiSearchService {
    private enum QueryTerm {
        case title(String)
        case tag(HitomiTagSuggestion.Namespace, String)
    }

    private let domain = "ltn.gold-usergeneratedcontent.net"
    private let maximumNodeSize: UInt64 = 464
    private let maximumTreeDepth = 32

    private var galleriesIndexVersion: String?
    private var languageIndexCache: [GalleryLanguage: [Int]] = [:]

    func galleryIDs(
        matching query: String,
        language: GalleryLanguage
    ) async throws -> [Int] {
        let terms = parseQuery(query)

        guard !terms.isEmpty else {
            return []
        }

        let languageIDs = try await galleryIDs(for: language)
        var matchingIDs = Set(languageIDs)

        for term in terms {
            let termIDs: [Int]

            switch term {
            case .title(let title):
                termIDs = try await galleryIDs(forTitleTerm: title)
            case .tag(let namespace, let name):
                termIDs = try await galleryIDs(
                    forTag: name,
                    namespace: namespace,
                    language: language
                )
            }

            matchingIDs.formIntersection(termIDs)

            if matchingIDs.isEmpty {
                return []
            }
        }

        return languageIDs.filter(matchingIDs.contains)
    }

    private func parseQuery(_ query: String) -> [QueryTerm] {
        query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .compactMap { rawTerm in
                let term = String(rawTerm)

                guard let separatorIndex = term.firstIndex(of: ":") else {
                    return .title(
                        term.replacingOccurrences(of: "_", with: " ")
                    )
                }

                let namespaceValue = String(term[..<separatorIndex])

                guard let namespace = HitomiTagSuggestion.Namespace(
                    rawValue: namespaceValue
                ) else {
                    return .title(
                        term.replacingOccurrences(of: "_", with: " ")
                    )
                }

                let nameStart = term.index(after: separatorIndex)
                let name = String(term[nameStart...])
                    .replacingOccurrences(of: "_", with: " ")

                guard !name.isEmpty else {
                    return nil
                }

                return .tag(namespace, name)
            }
    }

    private func galleryIDs(for language: GalleryLanguage) async throws -> [Int] {
        if let cachedIDs = languageIndexCache[language] {
            return cachedIDs
        }

        let url = try makeURL(path: "/index-\(language.rawValue).nozomi")
        let data = try await data(from: url)
        let galleryIDs = try decodeNozomi(data)
        languageIndexCache[language] = galleryIDs
        return galleryIDs
    }

    private func galleryIDs(
        forTag name: String,
        namespace: HitomiTagSuggestion.Namespace,
        language: GalleryLanguage
    ) async throws -> [Int] {
        let sanitizedName = name
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "#", with: "")
        let tagComponent: String

        switch namespace {
        case .male, .female:
            tagComponent = "\(namespace.rawValue):\(sanitizedName)"
        case .tag:
            tagComponent = sanitizedName
        }

        let path = "/tag/\(tagComponent)-\(language.rawValue).nozomi"
        let url = try makeURL(path: path)
        let data = try await data(from: url, notFoundIsEmpty: true)

        guard !data.isEmpty else {
            return []
        }

        return try decodeNozomi(data)
    }

    private func galleryIDs(forTitleTerm term: String) async throws -> [Int] {
        let version = try await currentGalleriesIndexVersion()
        let key = Array(
            SHA256.hash(data: Data(term.utf8)).prefix(4)
        )
        var nodeAddress: UInt64 = 0

        for _ in 0..<maximumTreeDepth {
            let node = try await indexNode(
                at: nodeAddress,
                version: version
            )
            let (found, position) = locate(key: key, in: node.keys)

            if found {
                return try await galleryIDs(
                    from: node.dataReferences[position],
                    version: version
                )
            }

            if node.subnodeAddresses.allSatisfy({ $0 == 0 }) {
                return []
            }

            guard node.subnodeAddresses.indices.contains(position) else {
                throw HitomiSearchError.invalidData
            }

            nodeAddress = node.subnodeAddresses[position]

            guard nodeAddress != 0 else {
                return []
            }
        }

        throw HitomiSearchError.invalidData
    }

    private func currentGalleriesIndexVersion() async throws -> String {
        if let galleriesIndexVersion {
            return galleriesIndexVersion
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/galleriesindex/version"
        components.queryItems = [
            URLQueryItem(name: "_", value: UUID().uuidString)
        ]

        guard let url = components.url else {
            throw HitomiSearchError.invalidURL
        }

        let versionData = try await data(from: url)

        guard let version = String(data: versionData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty else {
            throw HitomiSearchError.invalidData
        }

        galleriesIndexVersion = version
        return version
    }

    private func indexNode(
        at address: UInt64,
        version: String
    ) async throws -> SearchIndexNode {
        let url = try makeURL(
            path: "/galleriesindex/galleries.\(version).index"
        )
        let nodeData = try await data(
            from: url,
            range: address...(address + maximumNodeSize - 1)
        )

        return try SearchIndexNode(data: nodeData)
    }

    private func galleryIDs(
        from reference: SearchIndexDataReference,
        version: String
    ) async throws -> [Int] {
        guard reference.length > 0,
              reference.length <= 100_000_000 else {
            throw HitomiSearchError.invalidData
        }

        let url = try makeURL(
            path: "/galleriesindex/galleries.\(version).data"
        )
        let endOffset = reference.offset + UInt64(reference.length) - 1
        let resultData = try await data(
            from: url,
            range: reference.offset...endOffset
        )
        var reader = SearchDataReader(data: resultData)
        let count = Int(try reader.readInt32())

        guard count > 0,
              resultData.count == count * 4 + 4 else {
            throw HitomiSearchError.invalidData
        }

        var galleryIDs: [Int] = []
        galleryIDs.reserveCapacity(count)

        for _ in 0..<count {
            galleryIDs.append(Int(try reader.readInt32()))
        }

        return galleryIDs
    }

    private func locate(
        key: [UInt8],
        in nodeKeys: [[UInt8]]
    ) -> (Bool, Int) {
        for (index, nodeKey) in nodeKeys.enumerated() {
            let comparison = compare(key, nodeKey)

            if comparison <= 0 {
                return (comparison == 0, index)
            }
        }

        return (false, nodeKeys.count)
    }

    private func compare(_ lhs: [UInt8], _ rhs: [UInt8]) -> Int {
        for index in 0..<min(lhs.count, rhs.count) {
            if lhs[index] < rhs[index] {
                return -1
            }

            if lhs[index] > rhs[index] {
                return 1
            }
        }

        return 0
    }

    private func decodeNozomi(_ data: Data) throws -> [Int] {
        guard data.count.isMultiple(of: 4) else {
            throw HitomiSearchError.invalidData
        }

        var reader = SearchDataReader(data: data)
        var galleryIDs: [Int] = []
        galleryIDs.reserveCapacity(data.count / 4)

        while !reader.isAtEnd {
            galleryIDs.append(Int(try reader.readInt32()))
        }

        return galleryIDs
    }

    private func makeURL(path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = path

        guard let url = components.url else {
            throw HitomiSearchError.invalidURL
        }

        return url
    }

    private func data(
        from url: URL,
        range: ClosedRange<UInt64>? = nil,
        notFoundIsEmpty: Bool = false
    ) async throws -> Data {
        var request = URLRequest(url: url)

        if let range {
            request.setValue(
                "bytes=\(range.lowerBound)-\(range.upperBound)",
                forHTTPHeaderField: "Range"
            )
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HitomiSearchError.invalidResponse
        }

        if notFoundIsEmpty, httpResponse.statusCode == 404 {
            return Data()
        }

        if range != nil {
            guard httpResponse.statusCode == 206 else {
                throw HitomiSearchError.invalidResponse
            }
        } else {
            guard httpResponse.statusCode == 200 else {
                throw HitomiSearchError.invalidResponse
            }
        }

        return data
    }
}

nonisolated enum HitomiSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "検索URLを生成できませんでした。"
        case .invalidResponse:
            return "検索データを取得できませんでした。"
        case .invalidData:
            return "検索データを解析できませんでした。"
        }
    }
}

nonisolated private struct SearchIndexDataReference {
    let offset: UInt64
    let length: Int
}

nonisolated private struct SearchIndexNode {
    let keys: [[UInt8]]
    let dataReferences: [SearchIndexDataReference]
    let subnodeAddresses: [UInt64]

    init(data: Data) throws {
        var reader = SearchDataReader(data: data)
        let keyCount = Int(try reader.readInt32())

        guard (0...32).contains(keyCount) else {
            throw HitomiSearchError.invalidData
        }

        var keys: [[UInt8]] = []
        keys.reserveCapacity(keyCount)

        for _ in 0..<keyCount {
            let keySize = Int(try reader.readInt32())

            guard (1...32).contains(keySize) else {
                throw HitomiSearchError.invalidData
            }

            keys.append(try reader.readBytes(count: keySize))
        }

        let dataCount = Int(try reader.readInt32())

        guard dataCount == keyCount else {
            throw HitomiSearchError.invalidData
        }

        var dataReferences: [SearchIndexDataReference] = []
        dataReferences.reserveCapacity(dataCount)

        for _ in 0..<dataCount {
            dataReferences.append(
                SearchIndexDataReference(
                    offset: try reader.readUInt64(),
                    length: Int(try reader.readInt32())
                )
            )
        }

        var subnodeAddresses: [UInt64] = []
        subnodeAddresses.reserveCapacity(17)

        for _ in 0..<17 {
            subnodeAddresses.append(try reader.readUInt64())
        }

        self.keys = keys
        self.dataReferences = dataReferences
        self.subnodeAddresses = subnodeAddresses
    }
}

nonisolated private struct SearchDataReader {
    let data: Data
    private(set) var offset = 0

    var isAtEnd: Bool {
        offset == data.count
    }

    mutating func readInt32() throws -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    mutating func readUInt64() throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw HitomiSearchError.invalidData
        }

        var value: UInt64 = 0

        for byte in data[offset..<(offset + 8)] {
            value = (value << 8) | UInt64(byte)
        }

        offset += 8
        return value
    }

    mutating func readBytes(count: Int) throws -> [UInt8] {
        guard count >= 0,
              offset + count <= data.count else {
            throw HitomiSearchError.invalidData
        }

        let bytes = Array(data[offset..<(offset + count)])
        offset += count
        return bytes
    }

    private mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw HitomiSearchError.invalidData
        }

        var value: UInt32 = 0

        for byte in data[offset..<(offset + 4)] {
            value = (value << 8) | UInt32(byte)
        }

        offset += 4
        return value
    }
}
