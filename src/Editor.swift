import SwiftUI
import AppKit

// MARK: - Syntax highlighting (C / C++)
/// Minimal but readable C/C++ highlighter using NSAttributedString over the visible buffer.
enum Highlighter {
    static let keywords: Set<String> = [
        "auto","break","case","catch","class","const","continue","default","delete","do",
        "else","enum","explicit","extern","final","for","friend","goto","if","inline",
        "int","long","namespace","new","operator","override","private","protected","public",
        "register","return","short","signed","sizeof","static","struct","switch","template",
        "this","throw","try","typedef","typename","union","unsigned","using","virtual","void",
        "volatile","while","bool","char","double","float","constexpr","decltype","const_cast",
        "dynamic_cast","reinterpret_cast","static_cast","nullptr","true","false","alignas"
    ]

    static func tokens(for string: String) -> [(NSRange, NSColor)] {
        var result: [(NSRange, NSColor)] = []
        guard string.count > 0 else { return result }
        let ns = string as NSString
        let len = ns.length
        var i = 0
        func push(_ start: Int, _ end: Int, _ color: NSColor) {
            if end > start { result.append((NSRange(location: start, length: end - start), color)) }
        }
        while i < len {
            let ch = ns.character(at: i)
            if ch == UInt16(35) /* # */ {
                var j = i
                while j < len, ns.character(at: j) != 10 { j += 1 }
                push(i, j, NSColor.systemPurple); i = j; continue
            }
            if ch == 47, i + 1 < len, ns.character(at: i + 1) == 47 {   // // line comment
                var j = i
                while j < len, ns.character(at: j) != 10 { j += 1 }
                push(i, j, NSColor.systemGreen); i = j; continue
            }
            if ch == 47, i + 1 < len, ns.character(at: i + 1) == 42 {   // /* block comment */
                let close = ns.range(of: "*/", options: [], range: NSRange(location: i, length: len - i))
                let end = close.location != NSNotFound ? close.location + close.length : len
                push(i, end, NSColor.systemGreen); i = end; continue
            }
            if ch == 34 || ch == 39 {                                    // string / char literal
                var j = i + 1
                while j < len {
                    let c = ns.character(at: j)
                    if c == 92 { j += 2; continue }
                    if c == ch { j += 1; break }
                    j += 1
                }
                push(i, j, NSColor.systemOrange); i = j; continue
            }
            if ch >= 48 && ch <= 57 {                                    // number
                var j = i
                while j < len {
                    let c = ns.character(at: j)
                    let digit = (c >= 48 && c <= 57), hexLet = (c >= 97 && c <= 102) || (c >= 65 && c <= 70)
                    if digit || hexLet || c == 46 || c == 120 || c == 88 { j += 1 } else { break }
                }
                push(i, j, NSColor.systemTeal); i = j; continue
            }
            if isIdentStart(ch) {                                        // identifier / keyword
                var j = i
                while j < len, isIdentChar(ns.character(at: j)) { j += 1 }
                if Highlighter.keywords.contains(ns.substring(with: NSRange(location: i, length: j - i))) {
                    push(i, j, NSColor.systemPink)
                }
                i = j; continue
            }
            i += 1
        }
        return result
    }
    private static func isIdentStart(_ c: UInt16) -> Bool { c == 95 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
    private static func isIdentChar(_ c: UInt16) -> Bool { isIdentStart(c) || (c >= 48 && c <= 57) }
}

// MARK: - Editor text view
final class EditorTextView: NSTextView {
    weak var store: DocumentStore?
    weak var gutter: LineNumberView?
    var highlightEnabled = true

    override func didChangeText() {
        super.didChangeText()
        store?.text = string
        reportCursor()
        if highlightEnabled { highlight() }
        NotificationCenter.default.post(name: .gutterNeedsUpdate, object: self)
    }

    override var selectedRanges: [NSValue] {
        didSet { reportCursor() }
    }

    func reportCursor() {
        guard let store else { return }
        let range = selectedRange()
        let prefix = (string as NSString).substring(to: range.location)
        let line = prefix.components(separatedBy: "\n").count
        let lastNewline = (prefix as NSString).range(of: "\n", options: .backwards)
        let col = lastNewline.location == NSNotFound ? range.location + 1 : range.location - lastNewline.location
        store.cursorText = "行 \(line), 列 \(col)"
    }

    func highlight() {
        let tokens = Highlighter.tokens(for: string)
        guard let ts = textStorage else { return }
        ts.beginEditing()
        ts.setAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ], range: NSRange(location: 0, length: ts.length))
        for (range, color) in tokens { ts.addAttributes([.foregroundColor: color], range: range) }
        ts.endEditing()
    }
}

// MARK: - Line-number gutter
extension Notification.Name { static let gutterNeedsUpdate = Notification.Name("gutterNeedsUpdate") }

/// A fixed-width gutter that draws Dev-C++-style line numbers, synced to the editor's scroll.
final class LineNumberView: NSView {
    weak var textView: EditorTextView?
    let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    override var isFlipped: Bool { true }

    var gutterWidth: CGFloat {
        guard let tv = textView else { return 40 }
        let lines = (tv.string as NSString).components(separatedBy: "\n").count
        return 24 + CGFloat(String(lines).count) * 7 + 12
    }

    func ensureWidth() {
        let w = gutterWidth
        if abs(bounds.width - w) > 1 { setFrameSize(NSSize(width: w, height: bounds.height)) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.width - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
        guard let tv = textView, let lm = tv.layoutManager, let tcont = tv.textContainer else { return }
        if tv.string.isEmpty { return }

        let visible = tv.visibleRect
        let visibleGlyph = lm.glyphRange(forBoundingRect: visible, in: tcont)
        guard visibleGlyph.length > 0 else { return }
        let firstChar = lm.characterIndexForGlyph(at: max(0, visibleGlyph.location))
        let prefix = (tv.string as NSString).substring(to: firstChar)
        let firstLine = prefix.components(separatedBy: "\n").count

        var line = firstLine
        lm.enumerateLineFragments(forGlyphRange: visibleGlyph) { _, usedRect, _, _, _ in
            let y = usedRect.minY
            let str = "\(line)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: self.font,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(x: self.bounds.width - size.width - 10, y: y + (13 - size.height) / 2),
                     withAttributes: attrs)
            line += 1
        }
    }
}

// MARK: - SwiftUI wrapper
struct CodeEditorView: NSViewRepresentable {
    @ObservedObject var store: DocumentStore

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true

        let tv = EditorTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.allowsUndo = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.store = store

        let gutter = LineNumberView()
        gutter.textView = tv
        tv.gutter = gutter

        scroll.documentView = tv

        // Gutter overlay pinned to the clip view's left edge; on top of the text view.
        scroll.contentView.addSubview(gutter)
        gutter.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: scroll.contentView.bottomAnchor)
        ])
        gutter.widthAnchor.constraint(equalToConstant: gutter.gutterWidth).isActive = true
        // Reserve the gutter width so text doesn't sit underneath it.
        tv.textContainerInset = NSSize(width: gutter.gutterWidth, height: 8)

        var gutterObserver: NSObjectProtocol?
        gutterObserver = NotificationCenter.default.addObserver(forName: .gutterNeedsUpdate, object: tv, queue: .main) { [weak gutter, weak tv] _ in
            guard let gutter, let tv else { return }
            // update the reserved inset and width
            let w = gutter.gutterWidth
            gutter.widthAnchor.constraint(equalToConstant: w).isActive = false
            gutter.widthAnchor.constraint(equalToConstant: w).isActive = true
            tv.textContainerInset = NSSize(width: w, height: 8)
            gutter.needsDisplay = true
        }
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak gutter] _ in
            gutter?.needsDisplay = true
        }
        context.coordinator.gutterObserver = gutterObserver

        tv.string = store.text
        tv.highlight()
        DispatchQueue.main.async { tv.reportCursor() }
        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != store.text {
            tv.string = store.text
            tv.highlight()
            NotificationCenter.default.post(name: .gutterNeedsUpdate, object: tv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        weak var textView: EditorTextView?
        var gutterObserver: NSObjectProtocol?
    }
}
