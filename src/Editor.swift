import SwiftUI
import AppKit

// MARK: - 编辑器
// 使用 SwiftUI 原生 TextEditor：与底部面板/状态栏走完全相同的 SwiftUI 渲染
// 路径，保证代码文本必定显示、必定可输入（NSTextView 在 layer-backed 环境
// 下内容不合成到窗口的问题不再存在）。

struct CodeEditorView: View {
    @ObservedObject var store: DocumentStore

    var body: some View {
        TextEditor(text: $store.text)
            .font(.system(size: 13, design: .monospaced))
            .padding(6)
            .onChange(of: store.text) { _ in
                let lines = store.text.components(separatedBy: "\n").count
                store.cursorText = "行数 \(lines) · 字符 \(store.text.count)"
            }
    }
}
