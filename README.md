# EnKeyBoard

## 项目介绍

EnKeyBoard 是一个离线的 macOS 英文输入法，通过词首补全和有序跳跃字母匹配，减少输入长单词时的按键次数。界面采用简洁的横向候选框，每页显示 5 个候选，紧跟输入光标。

- 输入至少 5 个英文字母后显示候选，例如 `custo → customer`。
- 支持保留字母顺序的跳跃输入，例如 `itntnal → international`。
- 支持本机选词学习、添加个人词和导入词表。
- 不联网，不上传输入内容，不记录完整句子。

面向个人使用，要求 macOS 14 或更新版本，当前构建面向 Apple Silicon。应用使用本机临时签名，尚未进行公开分发公证。

## 技术架构

项目使用 Swift、InputMethodKit 和 AppKit，无第三方运行时依赖。

| 模块 | 职责 |
|---|---|
| `EnKeyBoard` | 通过 InputMethodKit 接收输入、维护输入会话；使用 AppKit 显示候选框和设置窗口 |
| `EnKeyBoardCore` | 词库加载、前缀与跳跃匹配、候选排序、组合输入状态，以及 SQLite 个人词库与学习记录 |
| `InputSourceSupport` | 输入源查询与用户主动切换到系统英文 |
| `enkeyboard-source` | 安装与卸载时注册、核对和禁用本项目输入源 |
| `NextWordPredictor` | 预留下一词预测接口，当前不启用 |

候选按完整词、前缀匹配、跳跃匹配分组排序，并结合词频与本机选词记录。跳跃匹配要求首字母相同、后续字母顺序一致；不做错字、颠倒字母或任意缩写纠正。

EnKeyBoard 注册为独立输入法，不作为系统的 ASCII 英文输入源。Fn/地球键与物理“中/英”键（Caps Lock 键位）由 macOS 原生机制处理，不使用全局键盘监听，也不需要辅助功能授权。

内置 89,968 条美式英文词，以 ESDB/SCOWL US size 60、variant 1 为基础，结合 SymSpell 提供的 Google Books Ngram 词频。来源与许可见 [Resources/Licenses](Resources/Licenses/)，构建来源和哈希见 [lexicon.provenance.json](Resources/lexicon.provenance.json)。常规构建和使用均离线。

## 安装流程

1. 安装 Apple Command Line Tools，并使用支持 Swift 6 的工具链；不必安装完整 Xcode。
2. 在项目目录运行：

   ```sh
   ./scripts/build.sh
   ./scripts/install.sh
   ```

   构建产物位于 `dist/EnKeyBoard.app`，安装到 `~/Library/Input Methods/EnKeyBoard.app`。

3. 打开“系统设置 → 键盘 → 文本输入 → 编辑”，添加英文分类中的 **EnKeyBoard**，同时保留 **ABC** 输入源。若新安装的输入法尚未显示，保存工作后退出 macOS 当前登录会话并重新登录，再打开设置。
4. 将“按 Fn/🌐 键”设置为“更改输入源”，并开启“使用中/英键切换到 ABC 及从 ABC 切回”。

可选：打开独立预览窗口查看候选界面。

```sh
open dist/EnKeyBoard.app --args --preview
```

## 使用方法

通过 Fn/地球键或系统输入法菜单选中 EnKeyBoard。它与其他输入法作为平等的输入源使用。

### 输入与选词

| 操作 | 效果 |
|---|---|
| `cust` | 只有 4 个字母，不显示候选 |
| `custo` | 显示候选，可选择 `customer` |
| `itntnal` | 有序跳跃匹配，可选择 `international` |
| 空格 | 提交选中的候选并加空格；无候选时提交原文 |
| 数字 1–5 | 提交当前页对应候选，不加空格 |
| ↑ / ↓ | 切换选中的候选 |
| Page Up / Page Down | 翻页；Mac 键盘通常为 Fn+↑ / Fn+↓ |
| Enter | 提交当前页第一项，不加空格；无候选时提交原文；无待输入文字时正常换行 |
| Esc | 提交原始字母并退出候选 |
| Backspace | 删除正在输入的最后一个字符 |
| ← / → / Tab | 先提交原文，再交给应用处理 |
| 逗号、句号等 | 提交选中的候选，再输入标点 |
| 撇号、连字符 | 继续输入 `don't`、`well-known` 等词 |

候选门槛只计算英文字母，撇号和连字符不计入。前缀词可能占据第一页，可补充字母或翻页找到跳跃匹配的词。

候选框左边缘与光标对齐，位于文字行正下方；下方空间不足时显示在上方。应用未提供有效光标坐标时，候选框隐藏。

### 设置与个人词库

从系统输入法菜单打开“设置与个人词库…”，可启停本机学习、手动添加词、导入 UTF-8 词表、清空学习记录或打开系统键盘设置。“切换到系统英文”菜单可主动选择系统英文输入源。

导入词表每行一个英文词，也接受 TSV/CSV 的第一列；允许撇号和连字符，不接受空格短语。以 `#` 开头的行视为注释。发现无效行时整次导入停止，不会部分写入。

学习只记录主动提交的候选词及次数，陌生词不会自动加入个人词库。清空学习记录会保留个人词。数据存于 `~/Library/Application Support/EnKeyBoard/learning.sqlite`。

### 卸载

需要保留个人词与学习记录时，先备份 `~/Library/Application Support/EnKeyBoard/`。在项目目录运行：

```sh
./scripts/uninstall.sh
```

阅读提示并输入 `UNINSTALL`。脚本会禁用本项目输入源，移除安装的应用、个人数据、偏好、缓存与本应用权限；不改动其他输入法或全局键盘设置。项目源码和构建产物保留。若菜单仍显示已移除的输入法，可保存工作后退出 macOS 当前登录会话并重新登录，以刷新系统缓存。
