import AppKit
import EnKeyBoardCore

@MainActor
final class Runtime {
    static let shared = Runtime()
    let engine: CompletionEngine
    let learning: LearningStore?
    let candidatePanel = CandidatePanel()
    lazy var preferences = PreferencesController(runtime: self)
    var startupError: String?
    var learnEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "learnEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "learnEnabled") }
    }
    let dataDirectory: URL
    private init() {
        if let override = ProcessInfo.processInfo.environment["ENKEYBOARD_DATA_DIR"] {
            dataDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("EnKeyBoard", isDirectory: true)
        }
        do {
            guard let url = Bundle.main.url(forResource: "lexicon", withExtension: "tsv") else {
                throw NSError(domain: "EnKeyBoard", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到词库，请重新构建应用。"])
            }
            let lexicon = try Lexicon(url: url)
            let store = try LearningStore(url: dataDirectory.appendingPathComponent("learning.sqlite"))
            lexicon.add(words: store.customWords)
            engine = CompletionEngine(lexicon: lexicon)
            learning = store
        } catch {
            // Preserve ordinary typing if resources or the local database cannot be loaded.
            engine = CompletionEngine(lexicon: Lexicon(entries: []))
            learning = nil; startupError = error.localizedDescription
        }
    }
    func learn(_ word: String?) {
        guard learnEnabled, let word else { return }
        do { try learning?.recordSelection(word) }
        catch { preferences.showError(error.localizedDescription) }
    }
    func add(words: [String]) throws {
        guard let learning else { throw VocabularyError.emptyLexicon }
        try learning.add(words: words)
        engine.lexicon.add(words: words)
    }
}
