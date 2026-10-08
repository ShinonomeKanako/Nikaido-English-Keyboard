import AppKit
import UniformTypeIdentifiers
import EnKeyBoardCore

@MainActor
final class PreferencesController: NSObject {
    private unowned let runtime: Runtime
    private var window: NSWindow?
    private let wordField = NSTextField()
    private let status = NSTextField(labelWithString: "")
    init(runtime: Runtime) { self.runtime = runtime }

    func show() {
        if window == nil { build() }
        updateStatus()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    private func build() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 420), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "EnKeyBoard 设置"
        window.isReleasedWhenClosed = false
        window.center()
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "英文补全与个人词库")
        title.font = .systemFont(ofSize: 19, weight: .semibold)
        stack.addArrangedSubview(title)
        let learning = NSButton(checkboxWithTitle: "在本机记住选词习惯", target: self, action: #selector(setLearning(_:)))
        learning.state = runtime.learnEnabled ? .on : .off
        stack.addArrangedSubview(learning)
        stack.addArrangedSubview(NSButton(title: "打开系统键盘设置…", target: self, action: #selector(openKeyboardSettings(_:))))
        let hint = NSTextField(wrappingLabelWithString: "中/英和 Fn 切换由 macOS 处理。请在系统键盘设置中启用中/英切换 ABC，并将 Fn 设为更改输入源。候选在至少 5 个字母后显示。")
        hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor
        hint.widthAnchor.constraint(equalToConstant: 424).isActive = true
        stack.addArrangedSubview(hint)
        wordField.placeholderString = "添加英文单词，例如 customer"
        wordField.widthAnchor.constraint(equalToConstant: 320).isActive = true
        let add = NSButton(title: "添加", target: self, action: #selector(addWord(_:)))
        stack.addArrangedSubview(NSStackView(views: [wordField, add]))
        let actions = NSStackView(views: [
            NSButton(title: "导入词表…", target: self, action: #selector(importWords(_:))),
            NSButton(title: "清空学习记录…", target: self, action: #selector(clearLearning(_:)))
        ])
        actions.spacing = 12
        stack.addArrangedSubview(actions)
        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        stack.addArrangedSubview(status)
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28)
            ])
        }
        self.window = window
    }
    private func updateStatus() {
        status.stringValue = "\(runtime.engine.lexicon.entries.count) 个词 · 系统原生输入源切换"
    }
    @objc private func setLearning(_ sender: NSButton) { runtime.learnEnabled = sender.state == .on }
    @objc private func openKeyboardSettings(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }
    @objc private func addWord(_ sender: Any?) {
        do {
            let word = Lexicon.normalize(wordField.stringValue)
            guard Lexicon.isValidWord(word) else { throw VocabularyError.invalidWord(word) }
            try runtime.add(words: [word]); wordField.stringValue = ""; updateStatus()
        } catch { showError(error.localizedDescription) }
    }
    @objc private func importWords(_ sender: Any?) {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.plainText, .commaSeparatedText, .tabSeparatedText]
        picker.allowsMultipleSelection = false
        picker.prompt = "导入"
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let words = try LearningStore.parseImport(text)
            try runtime.add(words: words)
            updateStatus()
            status.stringValue = "已导入 \(words.count) 个单词 · " + status.stringValue
        } catch { showError(error.localizedDescription) }
    }
    @objc private func clearLearning(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "清空选词学习记录？"
        alert.informativeText = "个人添加的单词会保留。"
        alert.addButton(withTitle: "清空"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try runtime.learning?.clearLearning(); updateStatus() }
        catch { showError(error.localizedDescription) }
    }
    func showError(_ message: String) {
        let alert = NSAlert(); alert.messageText = "EnKeyBoard"; alert.informativeText = message
        alert.runModal()
    }
}
