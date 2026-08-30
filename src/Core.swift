import Foundation
import AppKit

// MARK: - DocumentStore
/// Holds the editor buffer, current file, and the console (build/run output).
final class DocumentStore: ObservableObject {
    // Buffer text. Kept in sync with the NSTextView via delegate.
    @Published var text: String = ""
    @Published var fileURL: URL?
    @Published var console = ""
    @Published var status = "Idle"
    @Published var busy = false
    @Published var cursorText = "行 1, 列 1"
    @Published var activeTab = 0   // 0 = 编译(Compiler), 1 = 运行(Run), 2 = 信息(Messages)

    var fileName: String { fileURL?.lastPathComponent ?? "untitled.cpp" }
    var fileDir: URL { fileURL?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser }

    var isCppFile: Bool {
        ["cpp", "cc", "cxx", "hpp", "hh", "hxx"].contains(fileURL?.pathExtension.lowercased() ?? "cpp")
    }

    func newDocument() {
        text = DocumentStore.cppTemplate
        fileURL = nil
        console("— New file —\n")
        status = "New file"
    }

    func openPanel() {
        let p = NSOpenPanel()
        p.allowedFileTypes = ["c", "cpp", "cc", "cxx", "h", "hpp", "txt", "source"]
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        p.begin { [weak self] resp in
            guard resp == .OK, let url = p.url, let self else { return }
            do {
                let s = try String(contentsOf: url, encoding: .utf8)
                self.text = s
                self.fileURL = url
                self.status = "Opened \(url.lastPathComponent)"
                self.console = ""
            } catch {
                self.console("✗ Open failed: \(error.localizedDescription)\n")
            }
        }
    }

    func save(_ panelSave: Bool = false) {
        if let url = fileURL { write(to: url) }
        else {
            let p = NSSavePanel()
            p.allowedFileTypes = [isCppFile ? "cpp" : "c"]
            p.nameFieldStringValue = fileName
            p.begin { [weak self] resp in
                guard resp == .OK, let url = p.url, let self else { return }
                self.write(to: url)
            }
        }
    }

    private func write(to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            status = "Saved \(url.lastPathComponent)"
            console("✓ Saved \(url.lastPathComponent)\n")
        } catch {
            console("✗ Save failed: \(error.localizedDescription)\n")
        }
    }

    func console(_ line: String) {
        console += line
    }

    static let cppTemplate = """
    #include <iostream>
    using namespace std;

    int main() {
        cout << "Hello, Dev C++ for macOS!" << endl;
        return 0;
    }
    """

    static let cTemplate = """
    #include <stdio.h>

    int main(void) {
        printf("Hello, Dev C++ for macOS!\\n");
        return 0;
    }
    """
}

// MARK: - BuildService
/// Compiles the current source with clang/clang++ and optionally runs the result.
final class BuildService {
    private let store: DocumentStore
    init(store: DocumentStore) { self.store = store }

    /// Where the built executable will land (same folder as the source).
    private var objectURL: URL {
        let exe = (store.fileName as NSString).deletingPathExtension
        return store.fileDir.appendingPathComponent(exe)
    }

    func buildAndRun(run: Bool) {
        guard !store.busy else { return }
        // Must have a saved file to build (the real Dev-C++ builds the project on disk).
        if store.fileURL == nil {
            store.save(false)
            guard store.fileURL != nil else {
                store.console("请先保存文件，然后再编译。\n")
                return
            }
        }
        store.busy = true
        store.activeTab = 0
        let src = store.fileURL!.lastPathComponent
        let ext = store.fileURL?.pathExtension.lowercased() ?? "cpp"
        let compiler = ["c", "h"].contains(ext) ? "clang" : "clang++"
        let exe = objectURL
        let cmd = "\(compiler) -Wall -std=c++17 \(store.fileURL!.lastPathComponent) -o \(exe.lastPathComponent)"

        store.console("\n---------- 编译: \(src) ----------\n")
        store.console("gcc 命令:  \(cmd)\n\n")
        store.status = "编译中…"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: compiler == "clang" ? "/usr/bin/clang" : "/usr/bin/clang++")
        proc.arguments = ["-Wall", "-std=c++17", store.fileURL!.path, "-o", exe.path]
        proc.currentDirectoryURL = store.fileDir
        let pipe = Pipe(); proc.standardOutput = pipe; proc.standardError = pipe
        proc.terminationHandler = { [weak self] p in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self else { return }
                self.store.console(out)
                let errors = out.components(separatedBy: "error:").count - 1
                let warnings = out.components(separatedBy: "warning:").count - 1
                if p.terminationStatus == 0 {
                    self.store.console("\n编译结果：0 Errors, \(warnings) Warnings\n")
                    self.store.console("输出文件：\(exe.lastPathComponent)\n")
                    self.store.console("编译成功。\n")
                    self.store.status = "编译成功 (\(exe.lastPathComponent))"
                    if run { self.run(exe: exe) }
                } else {
                    self.store.console("\n编译结果：\(errors) Errors, \(warnings) Warnings\n")
                    self.store.console("编译失败。\n")
                    self.store.status = "编译失败 (\(errors) Errors)"
                }
                self.store.busy = false
            }
        }
        do { try proc.run() } catch {
            store.console("无法启动编译器：\(error.localizedDescription)\n")
            store.busy = false
        }
    }

    private func run(exe: URL) {
        store.activeTab = 1
        store.console("\n---------- 运行: \(exe.lastPathComponent) ----------\n")
        let proc = Process()
        proc.executableURL = exe
        proc.currentDirectoryURL = store.fileDir
        let pipe = Pipe(); proc.standardOutput = pipe; proc.standardError = pipe
        proc.terminationHandler = { [weak self] p in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                self?.store.console(out)
                self?.store.console("\n进程结束，退出码 = \(p.terminationStatus)\n")
                self?.store.status = "运行结束 (exit \(p.terminationStatus))"
            }
        }
        try? proc.run()
    }
}
