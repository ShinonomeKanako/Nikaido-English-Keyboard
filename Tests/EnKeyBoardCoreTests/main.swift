import Foundation
import EnKeyBoardCore

var assertionFailures = 0
func reportFailure(_ message: String, file: StaticString, line: UInt) {
    assertionFailures += 1
    print("FAIL \(file):\(line): \(message)")
}
func expectTrue(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value() { reportFailure("Expected true", file: file, line: line) }
}
func expectFalse(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value() { reportFailure("Expected false", file: file, line: line) }
}
func expectEqual<T: Equatable>(_ actual: T, _ expected: T,
                               file: StaticString = #filePath, line: UInt = #line) {
    if actual != expected { reportFailure("\(actual) != \(expected)", file: file, line: line) }
}
func expectThrows<T>(_ body: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try body(); reportFailure("Expected an error", file: file, line: line) } catch { }
}

let tests = CoreTests()
let cases: [(String, () throws -> Void)] = [
    ("exact/prefix priority", tests.testPrefixAndExactPriority),
    ("subsequence order, first letter, repeats", tests.testSubsequenceAnchoringOrderAndRepeatedLetters),
    ("trigger thresholds", tests.testTriggerThresholds),
    ("immutable match-group ordering", tests.testPrefixAlwaysBeforeSubsequence),
    ("learning within groups", tests.testLearningChangesOnlyWithinGroup),
    ("case, contractions, hyphens", tests.testCaseAndPunctuationWords),
    ("unknown words", tests.testUnknownWordsAndEmptyQueries),
    ("space/enter/escape/punctuation", tests.testCompositionCommitBoundaries),
    ("backspace and session isolation", tests.testBackspaceClearsMarkAndSessionIsolation),
    ("paging and number keys", tests.testCandidatePagingAndNumberSelection),
    ("mode-switch original commit", tests.testCommitOriginalForModeChangeDoesNotLearn),
    ("import validation", tests.testImportValidation),
    ("SQLite persistence and atomic import", tests.testLearningPersistenceAndAtomicImport),
    ("matcher extension", tests.testMatcherExtensionWithoutChangingEngine),
    ("prefix collision retains configured priority", tests.testPrefixCollisionIsNotHiddenByFrequency)
]
for (name, run) in cases {
    let before = assertionFailures
    do { try run() }
    catch { reportFailure(error.localizedDescription, file: #filePath, line: #line) }
    if before == assertionFailures { print("PASS \(name)") }
}
print("\(cases.count) checks, \(assertionFailures) failed assertions")
exit(assertionFailures == 0 ? 0 : 1)
