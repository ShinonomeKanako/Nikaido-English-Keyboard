import Foundation

public struct WordEntry: Equatable {
    public let word: String
    public let frequency: Double
    public let bytes: [UInt8]
    public let letterMask: UInt32

    public init(word: String, frequency: Double = 1) {
        self.word = word.lowercased()
        self.frequency = max(1, frequency)
        bytes = Array(self.word.utf8)
        letterMask = bytes.reduce(0) { mask, byte in
            (97...122).contains(byte) ? mask | (1 << UInt32(byte - 97)) : mask
        }
    }
}

public enum VocabularyError: LocalizedError {
    case invalidWord(String)
    case emptyLexicon
    public var errorDescription: String? {
        switch self {
        case .invalidWord(let word): return "Invalid English word: \(word)"
        case .emptyLexicon: return "The English dictionary is empty."
        }
    }
}

public final class Lexicon {
    public private(set) var entries: [WordEntry]
    private var exact: [String: WordEntry] = [:]
    private var firstLetter: [UInt8: [WordEntry]] = [:]

    public init(entries: [WordEntry]) {
        self.entries = []
        replace(entries)
    }

    public convenience init(url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let words = text.split(whereSeparator: \.isNewline).compactMap { line -> WordEntry? in
            if line.hasPrefix("#") { return nil }
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard let first = columns.first, Self.isValidWord(String(first)) else { return nil }
            return WordEntry(word: String(first), frequency: columns.count > 1 ? Double(columns[1]) ?? 1 : 1)
        }
        guard !words.isEmpty else { throw VocabularyError.emptyLexicon }
        self.init(entries: words)
    }

    public static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }

    public static func isValidWord(_ word: String) -> Bool {
        let bytes = Array(word.utf8)
        guard (1...80).contains(bytes.count), let first = bytes.first, let last = bytes.last,
              (97...122).contains(first), (97...122).contains(last) else { return false }
        return bytes.allSatisfy { (97...122).contains($0) || $0 == 39 || $0 == 45 }
    }

    public func add(words: [String]) {
        replace(entries + words.map { WordEntry(word: $0) })
    }

    private func replace(_ words: [WordEntry]) {
        exact = [:]
        for entry in words where Self.isValidWord(entry.word) {
            if (exact[entry.word]?.frequency ?? 0) <= entry.frequency { exact[entry.word] = entry }
        }
        entries = exact.values.sorted { $0.word < $1.word }
        firstLetter = Dictionary(grouping: entries, by: { $0.bytes[0] })
    }

    public func word(_ query: String) -> WordEntry? { exact[query] }
    public func starting(with byte: UInt8) -> [WordEntry] { firstLetter[byte] ?? [] }

    public func prefixed(by prefix: String) -> ArraySlice<WordEntry> {
        var lower = 0
        var upper = entries.count
        while lower < upper {
            let mid = (lower + upper) / 2
            if entries[mid].word < prefix { lower = mid + 1 } else { upper = mid }
        }
        let start = lower
        while lower < entries.count && entries[lower].word.hasPrefix(prefix) { lower += 1 }
        return entries[start..<lower]
    }
}
