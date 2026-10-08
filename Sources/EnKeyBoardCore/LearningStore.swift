import Foundation
import CSQLite

public final class LearningStore {
    private var database: OpaquePointer?
    public private(set) var counts: [String: Int] = [:]
    public private(set) var customWords: [String] = []
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &database) == SQLITE_OK else { throw error() }
        sqlite3_busy_timeout(database, 150)
        do {
            try execute("PRAGMA journal_mode=WAL")
            try execute("CREATE TABLE IF NOT EXISTS selections(word TEXT PRIMARY KEY, count INTEGER NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS custom_words(word TEXT PRIMARY KEY)")
            try reload()
        } catch {
            sqlite3_close(database); database = nil; throw error
        }
    }
    deinit { sqlite3_close(database) }

    private func error() -> NSError {
        NSError(domain: "EnKeyBoard.Storage", code: Int(sqlite3_errcode(database)),
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw error() }
    }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw error() }
        return statement
    }
    private func reload() throws {
        let statement = try prepare("SELECT word, count FROM selections")
        defer { sqlite3_finalize(statement) }
        counts = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            counts[String(cString: sqlite3_column_text(statement, 0))] = Int(sqlite3_column_int64(statement, 1))
        }
        let custom = try prepare("SELECT word FROM custom_words ORDER BY word")
        defer { sqlite3_finalize(custom) }
        customWords = []
        while sqlite3_step(custom) == SQLITE_ROW { customWords.append(String(cString: sqlite3_column_text(custom, 0))) }
    }

    public func recordSelection(_ word: String) throws {
        let word = Lexicon.normalize(word)
        guard Lexicon.isValidWord(word) else { throw VocabularyError.invalidWord(word) }
        let statement = try prepare("INSERT INTO selections VALUES(?, 1) ON CONFLICT(word) DO UPDATE SET count=count+1")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, word, -1, transient)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw error() }
        counts[word, default: 0] += 1
    }

    public func add(words: [String]) throws {
        let words = Array(Set(words.map(Lexicon.normalize))).sorted()
        for word in words where !Lexicon.isValidWord(word) { throw VocabularyError.invalidWord(word) }
        try execute("BEGIN IMMEDIATE")
        do {
            let statement = try prepare("INSERT OR IGNORE INTO custom_words VALUES(?)")
            defer { sqlite3_finalize(statement) }
            for word in words {
                sqlite3_reset(statement); sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, word, -1, transient)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw error() }
            }
            try execute("COMMIT")
            customWords = Array(Set(customWords + words)).sorted()
        } catch { try? execute("ROLLBACK"); throw error }
    }

    public func clearLearning() throws {
        try execute("DELETE FROM selections")
        counts = [:]
    }

    public static func parseImport(_ text: String) throws -> [String] {
        let words = text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            return Lexicon.normalize(String(trimmed.split(whereSeparator: { $0 == "\t" || $0 == "," }).first ?? ""))
        }
        for word in words where !Lexicon.isValidWord(word) { throw VocabularyError.invalidWord(word) }
        return Array(Set(words)).sorted()
    }
}
