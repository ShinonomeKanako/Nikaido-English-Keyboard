import AppKit
import EnKeyBoardCore

@MainActor
final class PreviewController: NSObject, NSTextFieldDelegate {
    private var window: NSWindow?
    private let input = NSTextField()
    private let result = NSTextField(wrappingLabelWithString: "")
    private lazy var session = CompositionSession(engine: Runtime.shared.engine) {
        Runtime.shared.learning?.counts ?? [:]
    }
    func show() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 300), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "EnKeyBoard · 候选预览"
        window.isReleasedWhenClosed = false
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "更少的字母，完整的英文")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        stack.addArrangedSubview(title)
        let hint = NSTextField(wrappingLabelWithString: "输入至少 5 个字母，如 custo 或 itntnal 查看候选。此窗口仅预览匹配与外观；系统按键与跨应用输入需自行验证。")
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)
        input.font = .systemFont(ofSize: 18)
        input.placeholderString = "输入单词的开头或跳跃字母"
        input.delegate = self
        input.widthAnchor.constraint(equalToConstant: 600).isActive = true
        stack.addArrangedSubview(input)
        result.textColor = .secondaryLabelColor
        stack.addArrangedSubview(result)
        let settings = NSButton(title: "设置与个人词库…", target: self, action: #selector(showSettings(_:)))
        stack.addArrangedSubview(settings)
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28)
            ])
        }
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(input)
        self.window = window
    }
    func controlTextDidChange(_ obj: Notification) {
        session.reset()
        _ = session.handle(.text(input.stringValue))
        displayCandidates()
    }
    private func displayCandidates() {
        guard let window else { return }
        let local = input.convert(input.bounds, to: nil)
        let anchor = window.convertToScreen(local)
        Runtime.shared.candidatePanel.show(session: session, caret: anchor, level: window.level.rawValue) { [weak self] number in
            guard let self else { return }
            let index = self.session.pageIndex * 5 + number - 1
            guard self.session.candidates.indices.contains(index) else { return }
            let candidate = self.session.candidates[index]
            self.result.stringValue = "已选择：\(candidate.display)"
            Runtime.shared.learn(candidate.word)
            Runtime.shared.candidatePanel.hide()
        }
        result.stringValue = "\(session.candidates.count) 个候选 · 点击候选可预览选择"
    }
    @objc private func showSettings(_ sender: Any?) { Runtime.shared.preferences.show() }
}
