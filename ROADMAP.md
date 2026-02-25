# Bewy Roadmap

> **Bewy** -- A modern, lightweight code editor built with Flutter.
>
> `[x]` Done &nbsp;&nbsp; `[ ]` To-do &nbsp;&nbsp; `[~]` Partial

---

## 1. Editor Core

| Status | Feature |
|:------:|---------|
| [x] | Multi-tab editing (open / close / switch / drag-reorder) |
| [x] | Pin / unpin tabs |
| [x] | Up to 3 editor groups (split view) |
| [x] | Move tabs between editor groups |
| [x] | Welcome page (recent files, folders, quick actions) |
| [x] | Undo / Redo with full history |
| [x] | Cut / Copy / Paste / Select All |
| [x] | Duplicate line up / down |
| [x] | Word wrap toggle |
| [x] | Auto-pair brackets & quotes (configurable) |
| [x] | Trim trailing whitespace on save |
| [x] | Configurable indent (spaces / tabs, size) |
| [x] | Line numbers |
| [x] | Current line highlight |
| [x] | Bracket matching highlight |
| [x] | Indent guides |
| [x] | Minimap with diagnostics markers & viewport slider |
| [x] | Breadcrumb navigation (path + directory dropdown) |
| [x] | Large file support (>10 000 lines, performance optimized) |
| [x] | Binary file detection (read-only prompt) |
| [x] | Font zoom (Ctrl +/-, Ctrl 0 reset, 8-40 pt) |
| [x] | Letter spacing adjustment (-1.0 ~ 6.0) |
| [x] | 4 monospace fonts (JetBrains Mono, Cascadia Code/Mono, Source Code Pro) |
| [x] | Zen mode (hide all panels, focus editing) |
| [ ] | Multi-cursor editing (Ctrl+D, Alt+Click) |
| [ ] | Column selection (Alt+Shift+Drag) |
| [ ] | Code folding (fold / unfold regions) |
| [ ] | Snippets (tab-completion templates) |
| [ ] | Rainbow bracket colorization |
| [ ] | Ruler lines (column guides) |
| [ ] | Sticky scroll (pin function headers) |

---

## 2. Find & Replace

| Status | Feature |
|:------:|---------|
| [x] | In-file find (Ctrl+F) |
| [x] | In-file replace (Ctrl+H) |
| [x] | Case-sensitive matching |
| [x] | Whole-word matching |
| [x] | Regex patterns |
| [x] | Replace single / replace all |
| [x] | Match counter |
| [x] | Workspace-wide search (cross-file) |
| [x] | Workspace-wide replace |
| [x] | Search result preview (file:line:col + context) |
| [x] | Search progress tracking |
| [x] | Click-to-navigate from results |
| [ ] | File include / exclude glob filter |
| [ ] | Search history |

---

## 3. Syntax & Diagnostics

### 3.1 Syntax Highlighting

| Status | Feature |
|:------:|---------|
| [x] | re_highlight-based syntax coloring |
| [x] | LSP semantic highlighting (token-based) |
| [ ] | Custom syntax / TextMate grammars |

### 3.2 Tree-sitter

| Status | Feature |
|:------:|---------|
| [x] | Native FFI bindings |
| [x] | Syntax error detection |
| [x] | Standalone diagnostics engine |
| [x] | Automatic full workspace scan |

### 3.3 LSP (Language Server Protocol)

| Status | Feature |
|:------:|---------|
| [x] | 28 languages supported |
| [x] | Real-time diagnostics (error / warning / info) |
| [x] | Quick Fix code actions (Ctrl+Shift+.) |
| [x] | Signature help (Ctrl+Shift+I) |
| [x] | Per-language LSP toggle |
| [x] | LSP server install management UI |
| [x] | Primary LSP pre-launch |
| [x] | Manual full-scan button in status bar |
| [x] | Scan exclude rules (directories / file patterns) |
| [x] | LSP connections panel |
| [ ] | Go to Definition |
| [ ] | Find References |
| [ ] | Hover Documentation |
| [ ] | Autocomplete (IntelliSense) |
| [ ] | Rename Symbol |
| [ ] | Document Symbols / Outline view |
| [ ] | Workspace Symbol Search |
| [ ] | Code Lens |
| [ ] | Inlay Hints |
| [ ] | Call Hierarchy |
| [ ] | Type Hierarchy |

---

## 4. Code Formatting

| Status | Feature |
|:------:|---------|
| [x] | Built-in Dart formatter (dart_style) |
| [x] | Built-in XML / SVG formatter |
| [x] | External CLI formatters (Prettier, Black, gofmt, rustfmt, clang-format, ...) |
| [x] | Format on save (optional) |
| [x] | Format result status notification |
| [ ] | Config file support (.prettierrc, .editorconfig, ...) |

---

## 5. File Management

### 5.1 File Explorer

| Status | Feature |
|:------:|---------|
| [x] | Tree-view directory structure |
| [x] | Expand / collapse directories |
| [x] | File type icons (multiple themes) |
| [x] | New file / folder |
| [x] | Delete with confirmation |
| [x] | Rename in-place |
| [x] | Copy / Cut / Paste |
| [x] | Context menu (right-click) |
| [x] | Drag-and-drop to open files |
| [x] | Reveal in system file explorer |
| [x] | File search filter |
| [x] | External change detection & auto-reload |
| [ ] | Git status coloring (modified / added / deleted) |
| [ ] | Drag to move files between directories |

### 5.2 Encoding & Line Endings

| Status | Feature |
|:------:|---------|
| [x] | 19 character encodings |
| [x] | Reopen with encoding |
| [x] | Save with encoding |
| [x] | Line ending toggle (LF / CRLF) |

### 5.3 Recent Files

| Status | Feature |
|:------:|---------|
| [x] | Recent files list (up to 100) |
| [x] | Recent folders list |
| [x] | Reopen last folder on startup (optional) |

---

## 6. Terminal

| Status | Feature |
|:------:|---------|
| [x] | xterm-based rendering |
| [x] | Multiple sessions |
| [x] | Create / close / switch sessions |
| [x] | Shell profile detection (CMD, PowerShell, bash, ...) |
| [x] | Terminal font size / spacing / line height config |
| [x] | Context menu |
| [x] | Shutdown WSL on close option |
| [ ] | Split terminal |
| [ ] | Clickable link detection |
| [ ] | Send selected text to terminal |

---

## 7. Bottom Panel

| Status | Feature |
|:------:|---------|
| [x] | Problems panel (group by file, severity filter, click-to-jump) |
| [x] | Terminal panel |
| [~] | Output panel (placeholder, pending stream integration) |
| [ ] | Debug console |
| [ ] | Source control panel (Git changes) |

---

## 8. Status Bar

| Status | Feature |
|:------:|---------|
| [x] | Line : Column position |
| [x] | Selection character / line count |
| [x] | Indent mode toggle (spaces / tabs + size) |
| [x] | Line ending display |
| [x] | Encoding selector |
| [x] | Language display |
| [x] | Word wrap toggle |
| [x] | Status notifications (success / error / info, auto-dismiss) |
| [x] | Sidebar / Editor / Panel toggle buttons |
| [x] | LSP connections button & panel |
| [x] | LSP full-scan button |
| [x] | Workspace scan progress bar |
| [x] | Check-for-updates button |
| [x] | Runtime logs button |

---

## 9. Title Bar & Menus

| Status | Feature |
|:------:|---------|
| [x] | Custom title bar (minimize / maximize / close) |
| [x] | Menu bar (File, Edit, Selection, View, Settings) |
| [x] | Global file search (fuzzy match, 120 ms debounce) |
| [x] | Go to Line (Ctrl+G) |
| [x] | Go to File (Ctrl+P) |

---

## 10. Keyboard Shortcuts

| Status | Feature |
|:------:|---------|
| [x] | 31 customizable shortcuts |
| [x] | Conflict detection |
| [x] | Export / Import config |
| [x] | Restore defaults |
| [x] | Shortcuts settings UI |

---

## 11. Themes & Appearance

| Status | Feature |
|:------:|---------|
| [x] | 6 color themes (Dark, Light, Dark Blue, Light Blue, Dark Purple, Light Purple) |
| [x] | 60+ color tokens (editor, UI, terminal, syntax, panels, ...) |
| [x] | Glassmorphism effects |
| [x] | 5 file icon themes (Classic, Material, Cupertino, Font Awesome, Phosphor) |
| [x] | 3 icon color schemes (Muted, Vivid, Monochrome) |
| [x] | UI font selection (Segoe UI, Noto Sans SC, Cascadia Code) |
| [ ] | Custom theme import |
| [ ] | Follow system dark / light mode |

---

## 12. Internationalization

| Status | Feature |
|:------:|---------|
| [x] | English (en_US) -- full |
| [x] | Simplified Chinese (zh_CN) -- full |
| [x] | Dynamic language switch (no restart) |
| [ ] | More locales (ja, ko, zh_TW, ...) |

---

## 13. Multi-Window

| Status | Feature |
|:------:|---------|
| [x] | Main window + child windows |
| [x] | Tab transfer across windows |
| [x] | Inter-window IPC |
| [x] | Child window lifecycle management |
| [x] | Unified unsaved-file collection on exit |

---

## 14. Settings & Persistence

| Status | Feature |
|:------:|---------|
| [x] | JSON config file |
| [x] | Auto-save (off / after delay / on focus lost) |
| [x] | Hot exit (snapshot on close, restore on restart) |
| [x] | Window size / position memory |
| [x] | Settings UI (General, Editor, Terminal, Syntax, Appearance, Shortcuts, ...) |
| [x] | Code statistics (by language / extension / lines / files, exportable) |
| [x] | Privacy statement & consent dialog |
| [x] | Open-source software info |
| [x] | Check for updates (dou.asia channel) |

---

## 15. Timeline

| Status | Feature |
|:------:|---------|
| [x] | File operation history (up to 500 events) |
| [x] | Operation type labels (created / changed / moved / renamed / deleted) |
| [x] | History comparison view |

---

## 16. Logging

| Status | Feature |
|:------:|---------|
| [x] | Structured, leveled logging |
| [x] | Per-component log categories |
| [x] | Runtime logs viewer |
| [x] | Auto-save log files |
| [x] | Flush logs on exit |

---

## 17. Planned Major Features

| Status | Feature |
|:------:|---------|
| [ ] | Git integration (diff, commit, branch, push, pull, blame, log) |
| [ ] | Debugger integration (DAP protocol, breakpoints, stepping, variables) |
| [ ] | Code runner (Run / Build button, task configuration) |
| [ ] | Plugin / extension system |
| [ ] | Remote development (SSH / WSL / Container) |
| [ ] | AI-assisted coding (Copilot-style completion / chat) |
| [ ] | Markdown live preview |
| [ ] | Image / PDF preview |
| [ ] | Diff editor (side-by-side compare & edit) |
| [ ] | Process manager (view / kill child processes) |
| [ ] | Notification center |
| [ ] | Command palette (Ctrl+Shift+P) |
| [ ] | Settings sync (cross-device) |
| [ ] | .editorconfig support |
