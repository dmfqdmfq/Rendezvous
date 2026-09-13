import Foundation
import Combine

@MainActor
final class GallerySearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var suggestions: [HitomiTagSuggestion] = []

    private let suggestionService = HitomiTagSuggestionService()
    private var suggestionTask: Task<Void, Never>?
    private var requestID = UUID()

    // MARK: - 候補更新

    // 入力中の最後の単語だけを対象にタグ候補を更新する
    func updateSuggestions(availableTags: [GalleryTag]) {
        suggestionTask?.cancel()

        let newRequestID = UUID()
        requestID = newRequestID

        guard let token = currentToken, !token.isEmpty else {
            suggestions = []
            return
        }

        let localSuggestions = localSuggestions(
            for: token,
            availableTags: availableTags
        )
        suggestions = Array(
            ranked(localSuggestions, for: token).prefix(12)
        )

        suggestionTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()

                guard let self else {
                    return
                }

                let remoteSuggestions = try await suggestionService
                    .suggestions(for: token)

                try Task.checkCancellation()

                guard requestID == newRequestID else {
                    return
                }

                suggestions = Array(
                    ranked(
                        merge(
                            remoteSuggestions,
                            with: localSuggestions
                        ),
                        for: token
                    )
                    .prefix(12)
                )
            } catch is CancellationError {
                return
            } catch let error as URLError where error.code == .cancelled {
                return
            } catch {
                // リモート候補を取得できない場合も、読み込み済みタグの候補は維持する
            }
        }
    }

    // 候補の選択は検索を実行せず、現在入力中の単語だけを置き換える
    func select(_ suggestion: HitomiTagSuggestion) {
        let replacement = suggestion.queryToken + " "

        if let whitespaceIndex = query.lastIndex(where: \Character.isWhitespace) {
            let prefixEnd = query.index(after: whitespaceIndex)
            query = String(query[..<prefixEnd]) + replacement
        } else {
            query = replacement
        }

        suggestions = []
    }

    func clearSuggestions() {
        suggestionTask?.cancel()
        requestID = UUID()
        suggestions = []
    }

    // MARK: - ローカル候補

    private var currentToken: String? {
        guard let lastCharacter = query.last,
              !lastCharacter.isWhitespace else {
            return nil
        }

        return query
            .split(whereSeparator: \Character.isWhitespace)
            .last
            .map(String.init)
    }

    private func localSuggestions(
        for token: String,
        availableTags: [GalleryTag]
    ) -> [HitomiTagSuggestion] {
        let (namespace, term) = namespaceAndTerm(for: token)
        let normalizedTerm = normalizedName(term)
        var seenIDs = Set<String>()

        return availableTags
            .map(HitomiTagSuggestion.init(tag:))
            .filter { suggestion in
                guard namespace == nil || suggestion.namespace == namespace else {
                    return false
                }

                return normalizedTerm.isEmpty || normalizedName(suggestion.name)
                    .contains(normalizedTerm)
            }
            .filter { seenIDs.insert($0.id).inserted }
    }

    // 完全一致、短い接頭辞補完、中間一致の順で候補を並べる
    private func ranked(
        _ suggestions: [HitomiTagSuggestion],
        for token: String
    ) -> [HitomiTagSuggestion] {
        let (_, rawTerm) = namespaceAndTerm(for: token)
        let term = normalizedName(rawTerm)

        return suggestions.sorted { lhs, rhs in
            let lhsRank = relevanceRank(for: lhs, term: term)
            let rhsRank = relevanceRank(for: rhs, term: term)

            if lhsRank.tier != rhsRank.tier {
                return lhsRank.tier < rhsRank.tier
            }

            if lhsRank.primaryDistance != rhsRank.primaryDistance {
                return lhsRank.primaryDistance < rhsRank.primaryDistance
            }

            if lhsRank.secondaryDistance != rhsRank.secondaryDistance {
                return lhsRank.secondaryDistance < rhsRank.secondaryDistance
            }

            let lhsCount = lhs.count ?? -1
            let rhsCount = rhs.count ?? -1

            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }

            let lhsPriority = namespacePriority(lhs.namespace)
            let rhsPriority = namespacePriority(rhs.namespace)

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                == .orderedAscending
        }
    }

    private func relevanceRank(
        for suggestion: HitomiTagSuggestion,
        term: String
    ) -> (tier: Int, primaryDistance: Int, secondaryDistance: Int) {
        let name = normalizedName(suggestion.name)

        if name == term {
            return (0, 0, 0)
        }

        if name.hasPrefix(term) {
            return (1, max(name.count - term.count, 0), 0)
        }

        if let range = name.range(of: term) {
            let position = name.distance(
                from: name.startIndex,
                to: range.lowerBound
            )
            return (2, position, max(name.count - term.count, 0))
        }

        return (3, name.count, name.count)
    }

    private func namespaceAndTerm(
        for token: String
    ) -> (HitomiTagSuggestion.Namespace?, String) {
        guard let separatorIndex = token.firstIndex(of: ":") else {
            return (nil, token)
        }

        let rawNamespace = String(token[..<separatorIndex]).lowercased()
        let termStart = token.index(after: separatorIndex)
        let term = String(token[termStart...])

        return (
            HitomiTagSuggestion.Namespace(rawValue: rawNamespace),
            term
        )
    }

    private func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
    }

    private func namespacePriority(
        _ namespace: HitomiTagSuggestion.Namespace
    ) -> Int {
        switch namespace {
        case .male:
            return 0
        case .female:
            return 1
        case .tag:
            return 2
        }
    }

    private func merge(
        _ primary: [HitomiTagSuggestion],
        with fallback: [HitomiTagSuggestion]
    ) -> [HitomiTagSuggestion] {
        var seenIDs = Set<String>()

        return (primary + fallback).filter {
            seenIDs.insert($0.id).inserted
        }
    }
}
