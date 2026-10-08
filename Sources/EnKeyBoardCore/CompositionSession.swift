import Foundation

public enum CompositionKey {
    case text(String), space, enter, escape, backspace, punctuation(String)
    case select(Int), move(Int), page(Int), commitOriginal
}
public enum CompositionEffect: Equatable {
    case mark(String)
    case commit(String, learnedWord: String?)
    case passthrough
}

// A session belongs to one client. No text buffer is shared across applications.
public final class CompositionSession {
    public private(set) var input = ""
    public private(set) var candidates: [Candidate] = []
    public private(set) var selectedIndex = 0
    public let pageSize = 5
    private let engine: CompletionEngine
    private let selections: () -> [String: Int]
    public init(engine: CompletionEngine, selections: @escaping () -> [String: Int] = { [:] }) {
        self.engine = engine; self.selections = selections
    }
    public var pageIndex: Int { selectedIndex / pageSize }
    public var pageCount: Int { max(1, (candidates.count + pageSize - 1) / pageSize) }
    public var visibleCandidates: ArraySlice<Candidate> {
        let start = min(pageIndex * pageSize, candidates.count)
        return candidates[start..<min(start + pageSize, candidates.count)]
    }
    public func refresh() {
        candidates = engine.candidates(for: input, selections: selections())
        selectedIndex = 0
    }
    public func reset() { input = ""; candidates = []; selectedIndex = 0 }

    public func handle(_ key: CompositionKey) -> [CompositionEffect] {
        switch key {
        case .text(let text):
            input += text; refresh(); return [.mark(input)]
        case .backspace:
            guard !input.isEmpty else { return [.passthrough] }
            input.removeLast(); refresh(); return [.mark(input)]
        case .space:
            guard !input.isEmpty else { return [.passthrough] }
            return commitSelected(suffix: " ")
        case .punctuation(let punctuation):
            guard !input.isEmpty else { return [.passthrough] }
            return commitSelected(suffix: punctuation)
        case .enter:
            guard !input.isEmpty else { return [.passthrough] }
            // Enter accepts the first item of the visible page, even after arrow selection.
            selectedIndex = pageIndex * pageSize
            return commitSelected(suffix: "")
        case .escape, .commitOriginal:
            guard !input.isEmpty else { return keyIsCommitOriginal(key) ? [] : [.passthrough] }
            let raw = input; reset(); return [.commit(raw, learnedWord: nil)]
        case .select(let number):
            let index = pageIndex * pageSize + number - 1
            guard (1...pageSize).contains(number), candidates.indices.contains(index) else { return [.passthrough] }
            selectedIndex = index
            return commitSelected(suffix: "")
        case .move(let delta):
            guard !candidates.isEmpty else { return [.passthrough] }
            selectedIndex = min(max(0, selectedIndex + delta), candidates.count - 1)
            return []
        case .page(let delta):
            guard !candidates.isEmpty else { return [.passthrough] }
            let next = min(max(0, pageIndex + delta), pageCount - 1)
            selectedIndex = next * pageSize
            return []
        }
    }
    private func keyIsCommitOriginal(_ key: CompositionKey) -> Bool {
        if case .commitOriginal = key { return true }; return false
    }
    private func commitSelected(suffix: String) -> [CompositionEffect] {
        let selected = candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
        let result = (selected?.display ?? input) + suffix
        let learned = selected?.word
        reset()
        return [.commit(result, learnedWord: learned)]
    }
}
