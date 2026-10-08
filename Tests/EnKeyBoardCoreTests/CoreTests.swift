import Foundation
import EnKeyBoardCore

final class CoreTests {
    private func engine() -> CompletionEngine {
        CompletionEngine(lexicon: Lexicon(entries: [
            WordEntry(word: "custom", frequency: 10), WordEntry(word: "customer", frequency: 100),
            WordEntry(word: "customers", frequency: 90), WordEntry(word: "international", frequency: 500),
            WordEntry(word: "internal", frequency: 1000), WordEntry(word: "interaction", frequency: 300),
            WordEntry(word: "doesn't", frequency: 100), WordEntry(word: "well-known", frequency: 100)
        ]))
    }
    func testPrefixAndExactPriority() {
        let engine = engine()
        expectEqual(engine.candidates(for: "custo").first?.word, "customer")
        expectEqual(engine.candidates(for: "custom").first?.word, "custom")
        expectEqual(engine.candidates(for: "custom", selections: ["customer": 10000]).first?.word, "custom")
    }
    func testSubsequenceAnchoringOrderAndRepeatedLetters() {
        let engine = engine()
        expectEqual(engine.candidates(for: "itntnal").first?.word, "international")
        expectFalse(engine.candidates(for: "tntnal").contains { $0.word == "international" })
        expectFalse(engine.candidates(for: "ialtn").contains { $0.word == "international" })
        expectFalse(engine.candidates(for: "innnn").contains { $0.word == "international" })
    }
    func testTriggerThresholds() {
        let engine = engine()
        expectTrue(engine.candidates(for: "c").isEmpty)
        expectTrue(engine.candidates(for: "cu").isEmpty)
        expectTrue(engine.candidates(for: "cust").isEmpty)
        expectFalse(engine.candidates(for: "custo").isEmpty)
        expectFalse(engine.candidates(for: "it").contains { $0.word == "international" })
        expectTrue(engine.candidates(for: "itn").isEmpty)
        expectTrue(engine.candidates(for: "itntn").contains { $0.word == "international" })
        expectTrue(engine.candidates(for: "well-").isEmpty)
    }
    func testPrefixAlwaysBeforeSubsequence() {
        let engine = CompletionEngine(lexicon: Lexicon(entries: [
            WordEntry(word: "intervention", frequency: 1), WordEntry(word: "intracellular", frequency: 1e12)
        ]))
        let matches = engine.candidates(for: "inter", selections: ["intracellular": 1000000])
        expectEqual(matches.first?.word, "intervention")
        expectTrue(matches.contains { $0.word == "intracellular" })
    }
    func testLearningChangesOnlyWithinGroup() {
        let engine = engine()
        expectEqual(engine.candidates(for: "custo", selections: ["custom": 20]).first?.word, "custom")
        expectEqual(engine.candidates(for: "custom", selections: ["customer": 500]).first?.word, "custom")
    }
    func testCaseAndPunctuationWords() {
        let engine = engine()
        expectEqual(engine.candidates(for: "Custo").first?.display, "Customer")
        expectEqual(engine.candidates(for: "CUSTO").first?.display, "CUSTOMER")
        expectEqual(engine.candidates(for: "doesn'").first?.display, "doesn't")
        expectEqual(engine.candidates(for: "well-k").first?.display, "well-known")
    }
    func testUnknownWordsAndEmptyQueries() {
        expectTrue(engine().candidates(for: "").isEmpty)
        expectTrue(engine().candidates(for: "xyzxyz").isEmpty)
        let session = CompositionSession(engine: engine())
        _ = session.handle(.text("xyzxyz"))
        expectEqual(session.handle(.space), [.commit("xyzxyz ", learnedWord: nil)])
    }
    func testCompositionCommitBoundaries() {
        let session = CompositionSession(engine: engine())
        _ = session.handle(.text("custo"))
        expectEqual(session.handle(.space), [.commit("customer ", learnedWord: "customer")])
        expectTrue(session.input.isEmpty)
        _ = session.handle(.text("custo"))
        _ = session.handle(.move(1))
        expectEqual(session.handle(.enter), [.commit("customer", learnedWord: "customer")])
        expectEqual(session.handle(.enter), [.passthrough])
        _ = session.handle(.text("custo"))
        expectEqual(session.handle(.escape), [.commit("custo", learnedWord: nil)])
        _ = session.handle(.text("Custo"))
        expectEqual(session.handle(.punctuation(",")), [.commit("Customer,", learnedWord: "customer")])
        _ = session.handle(.text("cust"))
        expectEqual(session.handle(.space), [.commit("cust ", learnedWord: nil)])
    }
    func testBackspaceClearsMarkAndSessionIsolation() {
        let first = CompositionSession(engine: engine())
        let second = CompositionSession(engine: engine())
        _ = first.handle(.text("c"))
        expectTrue(second.input.isEmpty)
        expectEqual(first.handle(.backspace), [.mark("")])
        expectEqual(first.handle(.backspace), [.passthrough])
        expectTrue(first.candidates.isEmpty)
    }
    func testCandidatePagingAndNumberSelection() {
        let lexicon = Lexicon(entries: (0..<13).map {
            WordEntry(word: "customer" + String(UnicodeScalar(97 + $0)!), frequency: Double(1000 - $0))
        })
        let session = CompositionSession(engine: CompletionEngine(lexicon: lexicon))
        _ = session.handle(.text("custo"))
        expectEqual(session.pageCount, 3)
        _ = session.handle(.page(1))
        expectEqual(session.selectedIndex, 5)
        let expected = session.candidates[6]
        expectEqual(session.handle(.select(2)), [.commit(expected.display, learnedWord: expected.word)])
        _ = session.handle(.text("custo"))
        _ = session.handle(.page(1))
        _ = session.handle(.move(2))
        let firstOnPage = session.visibleCandidates.first!
        expectEqual(session.handle(.enter), [.commit(firstOnPage.display, learnedWord: firstOnPage.word)])
        _ = session.handle(.text("custo"))
        _ = session.handle(.page(100))
        expectEqual(session.visibleCandidates.count, 3)
        expectEqual(session.handle(.select(5)), [.passthrough])
    }
    func testCommitOriginalForModeChangeDoesNotLearn() {
        let session = CompositionSession(engine: engine())
        expectTrue(session.handle(.commitOriginal).isEmpty)
        _ = session.handle(.text("custo"))
        expectEqual(session.handle(.commitOriginal), [.commit("custo", learnedWord: nil)])
        expectTrue(session.candidates.isEmpty)
    }
    func testImportValidation() throws {
        expectEqual(try LearningStore.parseImport("# words\nCustomer\nwell-known\ndon’t\ncustomer\n"), ["customer", "don't", "well-known"])
        expectThrows(try LearningStore.parseImport("valid\nnot a word\n"))
        expectFalse(Lexicon.isValidWord("-customer"))
        expectFalse(Lexicon.isValidWord("中文"))
    }
    func testLearningPersistenceAndAtomicImport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("learning.sqlite")
        do {
            let store = try LearningStore(url: url)
            try store.recordSelection("Customer")
            try store.recordSelection("customer")
            try store.add(words: ["myword", "don't"])
            expectThrows(try store.add(words: ["validword", "invalid word"]))
            expectFalse(store.customWords.contains("validword"))
        }
        let store = try LearningStore(url: url)
        expectEqual(store.counts["customer"], 2)
        expectEqual(store.customWords, ["don't", "myword"])
        try store.clearLearning()
        expectTrue(store.counts.isEmpty)
        expectEqual(store.customWords, ["don't", "myword"])
    }
    func testMatcherExtensionWithoutChangingEngine() {
        struct Abbreviation: WordMatcher {
            func matches(query: String, lexicon: Lexicon) -> [WordMatch] {
                guard query == "intnl", let entry = lexicon.word("international") else { return [] }
                return [WordMatch(entry: entry, kind: .subsequence, positions: [0, 2, 7, 12])]
            }
        }
        let engine = CompletionEngine(lexicon: engine().lexicon, matchers: [Abbreviation()])
        expectEqual(engine.candidates(for: "intnl").first?.word, "international")
    }
    func testPrefixCollisionIsNotHiddenByFrequency() {
        let engine = CompletionEngine(lexicon: Lexicon(entries: [
            WordEntry(word: "profligate", frequency: 1),
            WordEntry(word: "professional", frequency: 1e12)
        ]))
        expectEqual(engine.candidates(for: "profl").first?.word, "profligate")
        expectEqual(engine.candidates(for: "profsl").first?.word, "professional")
    }
}
