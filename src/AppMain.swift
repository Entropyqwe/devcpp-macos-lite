import SwiftUI
import AppKit

@main
struct DevCppMacApp: App {

    @StateObject private var store = DocumentStore()
    @State private var buildService: BuildService?

    var body: some Scene {
        WindowGroup("Dev C++ for macOS") {
            ContentView(store: store, build: buildService ?? BuildService(store: store))
                .frame(minWidth: 800, minHeight: 560)
                .navigationTitle(store.fileName)
                .onAppear {
                    buildService = buildService ?? BuildService(store: store)
                    if store.text.isEmpty { store.newDocument() }
                }
        }
        .commands {
            // —— 文件 ——
            CommandGroup(replacing: .newItem) {
                Button("新建") { store.newDocument() }.keyboardShortcut("n", modifiers: .command)
                Button("打开…") { store.openPanel() }.keyboardShortcut("o", modifiers: .command)
                Button("保存") { store.save(false) }.keyboardShortcut("s", modifiers: .command)
                Button("另存为…") { store.save(true) }.keyboardShortcut("S", modifiers: [.command, .shift])
            }
            CommandMenu("编译") {
                Button("编译 (Compile)") { buildService?.buildAndRun(run: false) }.keyboardShortcut("b", modifiers: .command)
                    .help("Windows: Ctrl+F9")
                Button("编译并运行 (Compile & Run)") { buildService?.buildAndRun(run: true) }.keyboardShortcut("r", modifiers: .command)
                    .help("Windows: F11")
                Button("运行 (Run)") { buildService?.buildAndRun(run: true) }  // run requires a build; done above
                    .keyboardShortcut("i", modifiers: [.command, .shift]).disabled(true)
                Divider()
                Button("清空编译输出") { store.console = ""; store.activeTab = 0 }.keyboardShortcut("k", modifiers: .command)
            }
            CommandMenu("搜索") {
                Button("查找…") {
                    NSApp.sendAction(Selector(("performFindPanelAction:")), to: nil, from: nil)
                }.keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("帮助") {
                Button("快捷键对照（Windows → Mac）") { store.showShortcutsHelp() }
                Button("关于 Dev C++ for macOS") { store.showAbout() }
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

// MARK: - Content
struct ContentView: View {
    @ObservedObject var store: DocumentStore
    let build: BuildService

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            CodeEditorView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            bottomPanel
            statusBar
        }
    }

    // —— Dev-C++ 风格工具栏：文件 | 编辑 | 查找 || 编译运行 ——
    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                toolbarIcon("doc.badge.plus", "新建", .command, "n") { store.newDocument() }
                toolbarIcon("folder", "打开", .command, "o") { store.openPanel() }
                toolbarIcon("square.and.arrow.down", "保存", .command, "s") { store.save(false) }
                ToolbarSeparator()
                toolbarIcon("arrow.uturn.backward", "撤销", .command, "z") { undo() }
                toolbarIcon("arrow.uturn.forward", "重做", [.command, .shift], "Z") { redo() }
                ToolbarSeparator()
                toolbarIcon("scissors", "剪切", .command, "x") { cut() }
                toolbarIcon("doc.on.doc", "复制", .command, "c") { copy() }
                toolbarIcon("doc.on.clipboard", "粘贴", .command, "v") { paste() }
                ToolbarSeparator()
                toolbarIcon("magnifyingglass", "查找", .command, "f") { find() }
                Spacer()
            }
            .padding(.horizontal, 8).padding(.top, 6)

            HStack(spacing: 4) {
                toolbarIcon("hammer", "编译", .command, "b") { build.buildAndRun(run: false) }
                toolbarIcon("play", "运行", [], "R") { build.buildAndRun(run: true) }
                toolbarIcon("play.square", "编译运行", .command, "r") { build.buildAndRun(run: true) }
                ToolbarSeparator()
                ToolbarButton("stop", "终止") { }
                Spacer()
                if store.busy {
                    ProgressView().controlSize(.small)
                    Text("正在编译…").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(store.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    // —— 底部选项卡面板（编译 / 运行 / 信息）——
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabHeader(0, "编译")
                tabHeader(1, "运行")
                tabHeader(2, "信息")
                Spacer()
                Button("清空") { store.console = "" }.font(.caption).padding(.horizontal, 6)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Text(consoleText)
                    .font(.custom("Menlo", size: 12).monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(6)
            }
            .frame(height: 180)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func tabHeader(_ idx: Int, _ title: String) -> some View {
        Button {
            store.activeTab = idx
        } label: {
            Text(title)
                .font(.system(size: 12, weight: store.activeTab == idx ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(store.activeTab == idx ? Color(nsColor: .selectedControlColor).opacity(0.25) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var consoleText: String {
        if store.activeTab == 1 { return store.console }               // 运行结果也放在同一控制台
        return store.console.isEmpty
            ? "请在工具栏点击「编译」或按 ⌘B 开始编译。"
            : store.console
    }

    // —— 状态栏（Dev-C++ 风格）——
    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(store.cursorText).font(.system(size: 11)).monospacedDigit()
            Divider().frame(height: 12)
            Text(store.fileName).font(.system(size: 11))
            Text("·  \(store.isCppFile ? "C++17" : "C")").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(store.status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // —— 工具栏按钮：图标在上，下方一行小字说明 ——
    private func toolbarIcon(_ icon: String, _ caption: String, _ mods: EventModifiers, _ key: Character, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                Text(caption)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 52)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(caption)
    }

    private func ToolbarSeparator() -> some View {
        Rectangle().fill(Color.gray.opacity(0.35)).frame(width: 1, height: 30).padding(.horizontal, 3)
    }

    private func ToolbarButton(_ icon: String, _ caption: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(caption)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 52)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(caption)
    }

    // —— 标准编辑动作（转发给首响应者）——
    private func undo() { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
    private func redo() { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
    private func cut()  { NSApp.sendAction(Selector(("cut:")), to: nil, from: nil) }
    private func copy() { NSApp.sendAction(Selector(("copy:")), to: nil, from: nil) }
    private func paste(){ NSApp.sendAction(Selector(("paste:")), to: nil, from: nil) }
    private func find() { NSApp.sendAction(Selector(("performFindPanelAction:")), to: nil, from: nil) }
}

struct SettingsView: View {
    @ObservedObject var store: DocumentStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dev C++ for macOS").font(.headline)
            Text("为教学而生的原生 C/C++ IDE，操作界面参照 Windows 版 Dev-C++。\n编译使用系统 clang（需已安装 Xcode 命令行工具）。")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 200)
    }
}

// MARK: - 帮助面板
extension DocumentStore {
    func showShortcutsHelp() {
        let msg = """
        快捷键对照（Windows → Mac）
        ─────────────────────────
        新建        Ctrl+N      →  ⌘N
        打开        Ctrl+O      →  ⌘O
        保存        Ctrl+S      →  ⌘S
        编译        Ctrl+F9     →  ⌘B
        编译并运行   F11        →  ⌘R
        运行        F10        →  ⌘⇧R（先编译）
        撤销        Ctrl+Z      →  ⌘Z
        重做        Ctrl+Y      →  ⌘⇧Z
        查找        Ctrl+F      →  ⌘F

        说明：macOS 的菜单栏在屏幕顶部；工具栏按钮与 Windows 版一致，用鼠标即可完成全部教学操作。
        """
        let a = NSAlert()
        a.messageText = "快捷键对照表"
        a.informativeText = msg
        a.addButton(withTitle: "好")
        a.runModal()
    }

    func showAbout() {
        let a = NSAlert()
        a.messageText = "Dev C++ for macOS"
        a.informativeText = "v1.1 — 面向教学的 Dev-C++ 兼容界面\n原生 SwiftUI 实现，AD-HOC 签名，非官方产品。"
        a.addButton(withTitle: "好")
        a.runModal()
    }
}
