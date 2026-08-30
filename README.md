# 民间精简 macOS 版本 Dev C++

> 民间精简 macOS 原生版 Dev C++，用来应付还在使用这款软件教学的老师。

一款为教学而生的 **macOS 原生 C/C++ IDE**，操作界面参照 Windows 版 Dev-C++ 设计（双排工具栏带小字标注、底部「编译」面板、状态栏），编译使用系统自带 `clang`，无需 Wine。

---

## 📦 快速开始（本机）

1. 双击 `DevCppMac.dmg` 挂载，把 `DevCppMac.app` 拖进 `/Applications`；
2. 首次打开若提示「无法验证开发者」→ **右键图标 → 打开 → 打开**；
3. 确认已安装 Xcode 命令行工具：`xcode-select --install`。

运行时快捷键：

| 操作 | macOS | Windows Dev-C++ 对应 |
|---|---|---|
| 编译 | ⌘B | Ctrl+F9 |
| 编译并运行 | ⌘R | F11 |
| 运行 | ⌘⇧R | F10 |
| 新建 / 打开 / 保存 | ⌘N / ⌘O / ⌘S | Ctrl+N / Ctrl+O / Ctrl+S |

> 注意：本机是 ad-hoc 签名、未 Apple 公证。**本机编译的本机程序不受 Gatekeeper 拦截**；详情见下方「异地机器使用方法」。

---

## 🖥️ 异地机器使用方法（把软件/源码拿到别的 Mac 上跑）

**先区分你带过去的是「源码」还是「编译好的程序」，处理方式完全不同：**

### 方法 A：带源码过去 → 在本机重新编译（推荐，零权限问题）

把整个仓库（`src/` + `build-mac.sh`）拷过去。那边机器只要有 macOS + Xcode 命令行工具，就会把自己编译出来的新程序，**不需要绕过任何签名限制，直接能跑**：

```sh
tar xzf 源码包.tar.gz          # 或直接拷贝本仓库
cd DevCppMac                   # 进入仓库目录
./build-mac.sh                 # 自动：编译 → 打包 .app → ad-hoc 签名
cp -R DevCppMac.app /Applications/   # 安装
```

- 前提：`xcode-select --install`
- 产物是**那台机器自己编译**的，本地程序不受 quarantine/公证拦截。

### 方法 B：带编译好的 `.dmg`/`.app` 过去 → 只需去掉「隔离标记」

跨机器/跨网络传输的程序会被 macOS 打上 `com.apple.quarantine` 隔离标记，首次打开被 Gatekeeper 拦截属正常现象。**这不是破解、也不是关系统防护**，只是告诉 macOS「这是我自己要的程序」，两种方式任选：

```sh
# 方式1：去掉隔离标记（推荐，一次即可）
xattr -dr com.apple.quarantine /Applications/DevCppMac.app

# 方式2：第一次右键图标 → 打开 → 再点「打开」
```

> ⚠️ 把 `.app` 放到 /Applications 前，先给它去掉隔离标记更省事。

### 需要 Xcode 命令行工具（clang）

```sh
xcode-select --install
```

### 关于「真签名」（可选，彻底无提示）

想要传预编译 `.dmg` 到任意 Mac **完全没有提示**，需要 **Apple Developer ID 签名 + 公证**（需付费 Apple 开发者账号）。没有账号时，**方法 A（发源码过去自编译）就是最干净的方式**。

---

## ✨ 功能

- C/C++ 源码编辑器：代码逐行清晰显示 + 直接输入
- 一键编译 / 编译并运行（`clang`/`clang++`，-std=c++17）
- Dev-C++ 风格底部「编译 / 运行 / 信息」选项卡面板 + 状态栏
- 菜单栏按 Dev-C++ 组织（文件/编辑/编译/搜索/帮助），帮助含快捷键对照表
- 多花哨功能略（MVP）：暂无工程管理、代码补全、语法高亮

## 📂 目录结构

```
.
├── DevCppMac.dmg          # 可直接下载安装的镜像（含 .app）
├── example_hello.cpp      # 测试样例：Hello World
├── build-mac.sh           # 源码 → .app 的一键编译打包脚本
├── AppIcon.icns           # 图标
└── src/                   # Swift 源码
    ├── AppMain.swift
    ├── Editor.swift
    └── Core.swift
```

## ⚖️ 说明

- 编写语言：原生 SwiftUI + AppKit（Apple Silicon arm64）。
- 许可：本项目为教学辅助用途。灵感来自开源 Dev-C++（GPL）的设计理念，但代码是全新用 Swift 重写的原生 macOS 实现，不含 Windows/Delphi 源码。
- 未 Apple 公证，ad-hoc 签名，请按自身信任决定是否使用。
