import Foundation
import EnKeyBoardCore

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}
let arguments = Array(CommandLine.arguments.dropFirst())
let lexiconPath = ProcessInfo.processInfo.environment["ENKEYBOARD_LEXICON"] ?? "Resources/lexicon.tsv"
do {
    let engine = CompletionEngine(lexicon: try Lexicon(url: URL(fileURLWithPath: lexiconPath)))
    if arguments.first == "--benchmark" {
        let fixturePath = arguments.count > 1 ? arguments[1] : "Tests/Fixtures/acceptance.tsv"
        let rows = try String(contentsOfFile: fixturePath, encoding: .utf8).split(whereSeparator: \.isNewline)
        var failed = 0
        var durations: [Double] = []
        for row in rows where !row.hasPrefix("#") {
            let columns = row.split(separator: "\t")
            guard columns.count == 2 else { continue }
            let start = DispatchTime.now().uptimeNanoseconds
            let candidates = engine.candidates(for: String(columns[0]), limit: 5)
            durations.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            let success = candidates.contains { $0.word == columns[1] }
            if !success { failed += 1 }
            print("\(success ? "PASS" : "FAIL") \(columns[0]) → \(candidates.map(\.display).joined(separator: ", ")) [expected \(columns[1])]")
        }
        let sorted = durations.sorted()
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        print(String(format: "Lexicon: %d words; passed: %d/%d; query p95: %.2f ms", engine.lexicon.entries.count, durations.count - failed, durations.count, p95))
        exit(failed == 0 ? 0 : 1)
    }
    guard let query = arguments.first else { fail("Usage: enkeyboard-cli QUERY | --benchmark [fixture.tsv]") }
    for candidate in engine.candidates(for: query, limit: 20) {
        print("\(candidate.display)\t\(candidate.kind)\t\(String(format: "%.3f", candidate.score))")
    }
} catch { fail(error.localizedDescription) }
