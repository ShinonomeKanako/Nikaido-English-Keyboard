import AppKit
import EnKeyBoardCore

@MainActor
final class CandidatePanel {
    private let panel: NSPanel
    private let stack = NSStackView()
    private var onSelect: ((Int) -> Void)?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.title = "EnKeyBoard 候选"
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 9
        background.layer?.borderWidth = 0.5
        background.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.contentView = background
        stack.orientation = .horizontal; stack.alignment = .centerY; stack.spacing = 5
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 8, bottom: 7, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])
    }

    func show(session: CompositionSession, caret: NSRect, level: Int, onSelect: @escaping (Int) -> Void) {
        guard !session.candidates.isEmpty, caret.origin.x.isFinite, caret.origin.y.isFinite,
              caret.width.isFinite, caret.height.isFinite, caret.height > 0 else { hide(); return }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(caret) || $0.frame.contains(caret.origin) })
        guard let screen else { hide(); return }
        let bounds = screen.visibleFrame
        self.onSelect = onSelect
        rebuild()
        let visible = Array(session.visibleCandidates)
        let buttonLimit = max(60, (bounds.width - 110) / CGFloat(visible.count))
        for (offset, candidate) in visible.enumerated() {
            let button = NSButton(title: "", target: self, action: #selector(choose(_:)))
            button.tag = offset + 1
            button.isBordered = false
            button.bezelStyle = .inline
            button.wantsLayer = true
            button.layer?.cornerRadius = 5
            let selected = session.selectedIndex == session.pageIndex * session.pageSize + offset
            button.layer?.backgroundColor = selected ? NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor : NSColor.clear.cgColor
            let title = NSMutableAttributedString(string: "\(offset + 1) ", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor
            ])
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            title.append(NSAttributedString(string: candidate.display, attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: selected ? .medium : .regular),
                .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph
            ]))
            button.attributedTitle = title
            button.toolTip = candidate.display
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: min(buttonLimit, title.size().width + 16)).isActive = true
            button.heightAnchor.constraint(equalToConstant: 29).isActive = true
            stack.addArrangedSubview(button)
        }
        if session.pageCount > 1 {
            let label = NSTextField(labelWithString: "\(session.pageIndex + 1)/\(session.pageCount)")
            label.font = .systemFont(ofSize: 10)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
        }
        let natural = stack.fittingSize
        let size = NSSize(width: min(max(120, natural.width), bounds.width - 16), height: max(43, natural.height))
        panel.level = NSWindow.Level(rawValue: max(Int(CGWindowLevelForKey(.floatingWindow)), level + 1))
        panel.setContentSize(size)
        reposition(caret: caret, level: level)
        panel.orderFrontRegardless()
    }
    func reposition(caret: NSRect, level: Int) {
        guard caret.origin.x.isFinite, caret.origin.y.isFinite, caret.width.isFinite,
              caret.height.isFinite, caret.height > 0,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(caret) || $0.frame.contains(caret.origin) })
        else { hide(); return }
        let bounds = screen.visibleFrame
        let size = panel.frame.size
        let x = min(max(caret.minX, bounds.minX + 4), bounds.maxX - size.width - 4)
        var y = caret.minY - size.height - 3
        if y < bounds.minY + 2 { y = min(caret.maxY + 3, bounds.maxY - size.height - 2) }
        panel.level = NSWindow.Level(rawValue: max(Int(CGWindowLevelForKey(.floatingWindow)), level + 1))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    private func rebuild() {
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
    }
    func hide() { panel.orderOut(nil); onSelect = nil }
    @objc private func choose(_ sender: NSButton) { onSelect?(sender.tag) }
}
