import AppKit
import InputMethodKit
import Carbon
import EnKeyBoardCore
import InputSourceSupport

@objc(EnKeyBoardInputController)
@MainActor
final class InputController: IMKInputController {
    private lazy var session = CompositionSession(engine: Runtime.shared.engine) {
        Runtime.shared.learnEnabled ? Runtime.shared.learning?.counts ?? [:] : [:]
    }
    private var active = false
    private var currentClient: (any IMKTextInput)?
    private var candidateTracking: Timer?

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]).rawValue)
    }

    override func activateServer(_ sender: Any!) {
        active = true
        currentClient = sender as? any IMKTextInput
    }

    override func deactivateServer(_ sender: Any!) {
        stopCandidateTracking()
        if let client = sender as? any IMKTextInput ?? currentClient { apply(session.handle(.commitOriginal), client: client) }
        active = false; currentClient = nil
        Runtime.shared.candidatePanel.hide()
    }

    override func commitComposition(_ sender: Any!) {
        stopCandidateTracking()
        if let client = sender as? any IMKTextInput ?? currentClient { apply(session.handle(.commitOriginal), client: client) }
        Runtime.shared.candidatePanel.hide()
    }

    override func hidePalettes() { stopCandidateTracking(); Runtime.shared.candidatePanel.hide() }
    override func inputControllerWillClose() {
        stopCandidateTracking()
        if let client = currentClient { apply(session.handle(.commitOriginal), client: client) }
        active = false; currentClient = nil
        Runtime.shared.candidatePanel.hide()
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? any IMKTextInput else { return false }
        currentClient = client
        guard event.type == .keyDown else {
            apply(session.handle(.commitOriginal), client: client)
            stopCandidateTracking(); Runtime.shared.candidatePanel.hide()
            return false
        }
        // Do not intercept app shortcuts, Option characters, dead keys or control sequences.
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty || server().lastKeyEventWasDeadKey() {
            apply(session.handle(.commitOriginal), client: client)
            stopCandidateTracking()
            Runtime.shared.candidatePanel.hide()
            return false
        }

        let text = event.characters ?? ""

        let key: CompositionKey
        switch event.keyCode {
        case 51: key = .backspace
        case 36, 76: key = .enter
        case 53: key = .escape
        case 49: key = .space
        case 125: key = .move(1)
        case 126: key = .move(-1)
        case 121: key = .page(1)
        case 116: key = .page(-1)
        case 123, 124, 48, 115, 119, 117:
            apply(session.handle(.commitOriginal), client: client)
            stopCandidateTracking()
            Runtime.shared.candidatePanel.hide()
            return false
        default:
            if Self.isLetterText(text) { key = .text(text) }
            else if (text == "'" || text == "-") && !session.input.isEmpty { key = .text(text) }
            else if let number = Int(text), (1...5).contains(number),
                    session.visibleCandidates.count >= number,
                    !event.modifierFlags.contains(.shift) { key = .select(number) }
            else if text.count == 1 && ",.;:!?()[]{}\"/\\@#$%&*+=<>_~`|".contains(text) { key = .punctuation(text) }
            else {
                apply(session.handle(.commitOriginal), client: client)
                stopCandidateTracking()
                Runtime.shared.candidatePanel.hide()
                return false
            }
        }
        let effects = session.handle(key)
        apply(effects, client: client)
        updatePanel(client: client)
        return !effects.contains(.passthrough)
    }

    private static let currentSelection = NSRange(location: NSNotFound, length: NSNotFound)
    private static func isLetterText(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) }
    }
    private func apply(_ effects: [CompositionEffect], client: any IMKTextInput) {
        for effect in effects {
            switch effect {
            case .mark(let text):
                client.setMarkedText(text, selectionRange: NSRange(location: text.utf16.count, length: 0), replacementRange: Self.currentSelection)
            case .commit(let text, let learned):
                client.insertText(text, replacementRange: Self.currentSelection)
                Runtime.shared.learn(learned)
            case .passthrough: break
            }
        }
    }
    private func updatePanel(client: any IMKTextInput) {
        guard active, !session.candidates.isEmpty else {
            stopCandidateTracking()
            Runtime.shared.candidatePanel.hide(); return
        }
        Runtime.shared.candidatePanel.show(session: session, caret: caretRect(client: client), level: Int(client.windowLevel())) { [weak self] number in
            guard let self, self.active, let client = self.currentClient else { return }
            self.apply(self.session.handle(.select(number)), client: client)
            self.updatePanel(client: client)
        }
        if candidateTracking == nil {
            let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(trackCandidates(_:)), userInfo: nil, repeats: true)
            candidateTracking = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    @objc private func trackCandidates(_ timer: Timer) {
        guard active, !session.candidates.isEmpty, let client = currentClient else { stopCandidateTracking(); return }
        Runtime.shared.candidatePanel.reposition(caret: caretRect(client: client), level: Int(client.windowLevel()))
    }
    private func stopCandidateTracking() { candidateTracking?.invalidate(); candidateTracking = nil }
    private func caretRect(client: any IMKTextInput) -> NSRect {
        var rect = NSRect.zero
        // The range is relative to the marked text, not the entire document.
        let marked = client.markedRange()
        let selected = client.selectedRange()
        let index: Int
        if marked.location == NSNotFound { index = 0 }
        else if selected.location != NSNotFound,
           selected.location >= marked.location,
           selected.location - marked.location <= session.input.utf16.count {
            index = selected.location - marked.location
        } else { index = session.input.utf16.count }
        _ = client.attributes(forCharacterIndex: index, lineHeightRectangle: &rect)
        // Some clients reject the one-past-end index; retry the last marked character.
        if rect == .zero && index > 0 {
            _ = client.attributes(forCharacterIndex: index - 1, lineHeightRectangle: &rect)
            if rect.width > 0 { rect.origin.x = rect.maxX; rect.size.width = 1 }
        }
        return rect
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "切换到系统英文", action: #selector(switchToSystemEnglish(_:)), keyEquivalent: "")
        toggle.target = self; menu.addItem(toggle)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置与个人词库…", action: #selector(openSettings(_:)), keyEquivalent: "")
        settings.target = self; menu.addItem(settings)
        return menu
    }
    @objc private func switchToSystemEnglish(_ sender: Any?) {
        // Only the user's explicit menu command selects a source. Caps/Fn are
        // handled entirely by macOS, including the return from ABC.
        if let client = currentClient { apply(session.handle(.commitOriginal), client: client) }
        stopCandidateTracking()
        Runtime.shared.candidatePanel.hide()
        guard let native = InputSources.nativeEnglish() else {
            Runtime.shared.preferences.showError("请先在系统输入源中启用 ABC 或 U.S.。")
            return
        }
        if TISSelectInputSource(native) != noErr {
            Runtime.shared.preferences.showError("系统未能切换到英文输入源。")
        }
    }
    @objc private func openSettings(_ sender: Any?) {
        if let client = currentClient { apply(session.handle(.commitOriginal), client: client) }
        stopCandidateTracking()
        Runtime.shared.candidatePanel.hide()
        Runtime.shared.preferences.show()
    }
}
