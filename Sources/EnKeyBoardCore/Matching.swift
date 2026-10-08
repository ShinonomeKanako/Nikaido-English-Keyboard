import Foundation

public enum MatchKind: Int, Comparable {
    case exact, prefix, subsequence
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct WordMatch {
    public let entry: WordEntry
    public let kind: MatchKind
    public let positions: [Int]
    public init(entry: WordEntry, kind: MatchKind, positions: [Int]) {
        self.entry = entry; self.kind = kind; self.positions = positions
    }
}

// Future typo and abbreviation providers implement this contract without changing IMK code.
public protocol WordMatcher {
    func matches(query: String, lexicon: Lexicon) -> [WordMatch]
}

public struct ExactMatcher: WordMatcher {
    public init() {}
    public func matches(query: String, lexicon: Lexicon) -> [WordMatch] {
        guard let entry = lexicon.word(query) else { return [] }
        return [WordMatch(entry: entry, kind: .exact, positions: Array(entry.bytes.indices))]
    }
}

public struct PrefixMatcher: WordMatcher {
    public let minimumLength: Int
    public init(minimumLength: Int = 5) { self.minimumLength = minimumLength }
    public func matches(query: String, lexicon: Lexicon) -> [WordMatch] {
        guard query.utf8.count >= minimumLength else { return [] }
        return lexicon.prefixed(by: query).filter { $0.word != query }.map {
            WordMatch(entry: $0, kind: .prefix, positions: Array(0..<query.utf8.count))
        }
    }
}

public struct SubsequenceMatcher: WordMatcher {
    public let minimumLength: Int
    public init(minimumLength: Int = 5) { self.minimumLength = minimumLength }
    public func matches(query: String, lexicon: Lexicon) -> [WordMatch] {
        let needle = Array(query.utf8)
        guard needle.count >= minimumLength, let first = needle.first else { return [] }
        let queryMask = WordEntry(word: query).letterMask
        return lexicon.starting(with: first).compactMap { entry in
            guard entry.bytes.count >= needle.count, entry.letterMask & queryMask == queryMask,
                  !entry.word.hasPrefix(query) else { return nil }
            var positions = [0]
            var offset = 1
            for byte in needle.dropFirst() {
                while offset < entry.bytes.count && entry.bytes[offset] != byte { offset += 1 }
                guard offset < entry.bytes.count else { return nil }
                positions.append(offset)
                offset += 1
            }
            return WordMatch(entry: entry, kind: .subsequence, positions: positions)
        }
    }
}

public struct Candidate: Equatable {
    public let word: String
    public let display: String
    public let kind: MatchKind
    public let positions: [Int]
    public let score: Double
}

public protocol CandidateRanker {
    func score(match: WordMatch, selectionCount: Int) -> Double
}

public struct FrequencyRanker: CandidateRanker {
    public init() {}
    public func score(match: WordMatch, selectionCount: Int) -> Double {
        let gaps = (match.positions.last ?? 0) + 1 - match.positions.count
        return log10(match.entry.frequency + 1) * 0.8
            + log2(Double(selectionCount) + 1) * 2.5
            - Double(gaps) * 0.12 - Double(match.entry.bytes.count) * 0.035
    }
}

public final class CompletionEngine {
    public let lexicon: Lexicon
    private let matchers: [any WordMatcher]
    private let ranker: any CandidateRanker
    public init(lexicon: Lexicon,
                matchers: [any WordMatcher] = [ExactMatcher(), PrefixMatcher(), SubsequenceMatcher()],
                ranker: any CandidateRanker = FrequencyRanker()) {
        self.lexicon = lexicon; self.matchers = matchers; self.ranker = ranker
    }

    public func candidates(for rawInput: String, selections: [String: Int] = [:], limit: Int = 100) -> [Candidate] {
        let query = Lexicon.normalize(rawInput)
        guard query.utf8.filter({ (97...122).contains($0) }).count >= 5,
              Lexicon.isValidWord(query) || query.last == "'" || query.last == "-" else { return [] }
        var best: [String: Candidate] = [:]
        for matcher in matchers {
            for match in matcher.matches(query: query, lexicon: lexicon) {
                let candidate = Candidate(word: match.entry.word,
                    display: Self.applyCase(rawInput, to: match.entry.word), kind: match.kind,
                    positions: match.positions, score: ranker.score(match: match, selectionCount: selections[match.entry.word] ?? 0))
                if let previous = best[candidate.word], previous.kind <= candidate.kind { continue }
                best[candidate.word] = candidate
            }
        }
        return Array(best.values.sorted {
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.word < $1.word
        }.prefix(max(0, limit)))
    }

    public static func applyCase(_ input: String, to word: String) -> String {
        let letters = input.filter { $0.isLetter }
        if !letters.isEmpty && letters == letters.uppercased() { return word.uppercased() }
        if let first = letters.first, String(first) == String(first).uppercased() {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return word
    }
}

// Reserved for future next-word prediction. The first release never calls a provider.
public struct PredictionContext {
    public let precedingWords: [String]
    public init(precedingWords: [String]) { self.precedingWords = precedingWords }
}
public protocol NextWordPredictor {
    func predict(context: PredictionContext, limit: Int) -> [String]
}
