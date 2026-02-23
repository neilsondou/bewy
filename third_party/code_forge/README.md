<h1 align="center">⚒️ CodeForge</h1>

<p align="center">
  <strong>A powerful, feature-rich code editor created using Flutter</strong>
</p>

<p align="center">
  <em>Bring VS Code-level editing experience to your Flutter apps</em>
</p>

<p align="center">
  A complete and better alternative for <a href=https://pub.dev/packages/re_editor>re_editor</a>, <a href=https://pub.dev/packages/flutter_code_crafter>flutter_code_crafter</a>, <a href=https://pub.dev/packages/flutter_code_editor>flutter_code_editor</a>, <a href =https://pub.dev/packages/code_text_field>code_text_field</a>, etc
</p>

<p align="center">
  <a href="https://pub.dev/packages/code_forge">
    <img src="https://img.shields.io/pub/v/code_forge.svg?style=for-the-badge&logo=dart&logoColor=white&labelColor=0175C2&color=02569B" alt="Pub Version"/>
  </a>
  <a href="https://github.com/heckmon/code_forge/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge&labelColor=333333&color=4CAF50" alt="License"/>
  </a>
  <a href="https://github.com/heckmon/code_forge/stargazers">
    <img src="https://img.shields.io/github/stars/heckmon/code_forge.svg?style=for-the-badge&logo=github&labelColor=333333&color=FFD700" alt="GitHub Stars"/>
  </a>
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Platform-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Platform"/>
  </a>
</p>

---

<p align="center">
  <img src="https://raw.githubusercontent.com/heckmon/code_forge/refs/heads/main/gifs/code_forge_100k.gif" alt="CodeForge Demo" width="800"/><sub><br>large code support (tested with 100k+ lines) and LSP based intelligent lazy highlighting</sub>
</p>

> [!NOTE]
>
> code_forge does **not** support Flutter web, as it relies on `dart:io` for core functionality. Use [code_forge_web](https://pub.dev/packages/code_forge_web) for web support.


### What's new in 8.4.0
 - FEATURE: [#39](https://github.com/heckmon/code_forge/issues/39)
 - FIX: html/xml guide lines.

## Why CodeForge?
**Feature demos:** [CodeForge Features Showcase](https://heckmon.github.io/code_forge_demo/)

**CodeForge** is a next-generation code editor widget designed for developers who demand more. Whether you're building an IDE, a code snippet viewer, or an educational coding platform, CodeForge delivers:


| Feature | CodeForge | Others |
|---------|:---------:|:------:|
| Syntax Highlighting | 180+ languages<br>[Availabe languages](https://github.com/reqable/re-highlight/tree/main/lib/languages) | ✅ |
| Code Folding | Smart detection | ⚠️ Limited |
| LSP Integration | Full support | ❌ |
| AI Completion | Multi-model | ❌ |
| Semantic Tokens | Real-time | ❌ |
| Diagnostics | Inline errors | ❌ |
| Undo/Redo | Smart grouping | ⚠️ Basic |
| Full Theming |[Available themes](https://github.com/reqable/re-highlight/tree/main/lib/styles) | ⚠️ Limited |

### What makes CodeForge different from other editors:
- Uses the rope data structure instead of regular char array to to handle large text.
- Uses flutter's low level `RenderBox` and `ParagrahBuilder` to render text insted of `TextField` for efficiency.
- Built in [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) client
- AI Code completion.

---

To see working examples of all CodeForge features including AI Code Completion, LSP Integration, Smart Code Folding, Syntax Highlighting, Search and Replace, and RTL Language Support, visit the features showcase page above.

### 🌟 More Features

<details>
<summary><strong>📋 Complete Feature List</strong></summary>

#### Editor Core
- **Rope Data Structure** — Optimized for large files
- **180+ Languages** — Via `re_highlight` package
- **Code Folding** — Smart block detection
- **Indentation Guides** — Visual code structure
- **Line Numbers** — With active line highlighting
- **Smart Undo/Redo** — Timestamp-based grouping
- **Search Highlighting** — Find and highlight matches
- **Line Operations** — Move, duplicate, delete lines

#### LSP Features
- **Intelligent Completions** — Context-aware code suggestions with auto-import
- **Hover Documentation** — Rich markdown tooltips with type information
- **Real-time Diagnostics** — Errors and warnings with quick fixes
- **Semantic Highlighting** — Token-based coloring with modifiers
- **Signature Help** — Function signatures and parameter hints
- **Code Actions** — Quick fixes and refactoring suggestions
- **Inlay Hints** — Inline annotations for types and parameters
- **Document Highlight** — Highlight symbol occurrences
- **Document Colors** — Color value detection and picker
- **Go to Definition** — Navigate to symbol definitions
- **Symbol Renaming** — Rename symbols across workspace
- **Multiple Protocols** — Stdio and WebSocket support
- **Capability Control** — Selectively enable/disable LSP features

#### Customization
- **Full Theming** — Every element customizable
- **Gutter Styling** — Colors, icons, sizes
- **Selection Styling** — Cursor, selection, bubbles
- **Popup Styling** — Suggestions, hover details

</details>

---

## 📦 Installation

Add CodeForge to your `pubspec.yaml`:

```yaml
dependencies:
  code_forge: ^8.4.1
```

Then run:

```bash
flutter pub get
```

---

## 🚀 Quick Start

### Basic Usage

Import a theme and a language from the [re_highlight](https://pub.dev/packages/re_highlight) package and you are good to go. (Defaults to `langDart` and `vs2015Theme`):

```dart
import 'package:flutter/material.dart';
import 'package:code_forge/code_forge.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CodeForge(
          language: langPython, // Defaults to langDart
          editorTheme: atomOneDarkTheme, // Defaults to vs2015Theme
        ),
      ),
    );
  }
}
```

### With Controller

For more control over the editor:

```dart
class _EditorState extends State<Editor> {
  final _controller = CodeForgeController();
  final _undoController = UndoRedoController();

  @override
  Widget build(BuildContext context) {
    return CodeForge(
      controller: _controller, // Optional controller for more features.
      undoController: _undoController, // Optional undo controller to control the undo-redo operations.
    );
  }
}
```

---

<details>

<summary><h2>🔌 LSP Integration</h2></summary>

Connect to any Language Server Protocol compatible server for intelligent code assistance.

CodeForge provides a built-in LSP client that allows you to connect to any LSP server for intelligent highlighting, completions, hover details, diagnostics, and more.

## Types
#### There are two ways to configure LSP client with the `CodeForge`:
1. Using WebSocket (easy and recommended)
2. Using stdio

<details>
<summary><h3>1. Using WebSocket</h3></summary>

The class `LspSocketConfig` is used to connect to an LSP server using WebSocket. It takes the following parameters:
- `serverUrl`: The WebSocket URL of the LSP server.
- `filePath`: A filePath is required by the LSP server to provide completions and diagnostics.
- `workspacePath`: The workspace path is the current directory or the parent directory which holds the `filePath` file.
- `languageId`: This is a server specific parameter. eg: `'python'` is the language ID used in basedpyright/pyright language server.

You can easily start any language server using websocket using the  [lsp-ws-proxy](https://github.com/qualified/lsp-ws-proxy) package. For example, to start the basedpyright language server, you can use the following command:<br>
(On Android, you can use [Termux](https://github.com/termux/termux-app))

```bash
cd /Downloads/lsp-ws-proxy_linux # Navigate to the directory where lsp-ws-proxy is located

./lsp-ws-proxy --listen 5656 -- basedpyright-langserver --stdio # Start the pyright language server on port 5656
```

#### Example:
create a `LspSocketConfig` object and pass it to the `CodeForgeController` widget.

```dart
final lspConfig = LspSocketConfig(
    workspacePath: "/home/athul/Projects/lsp",
    languageId: "python",
    serverUrl: "ws://localhost:5656"
),
```
Then pass the `lspConfig` instance to the `CodeForgeController` widget:

```dart
final _controller = CodeForgeController(
  lspConfig: lspConfig // Pass the LspConfig here.
)

CodeForge(
    controller: _controller, // Pass the controller here.
    theme: anOldHopeTheme,
    filePath: "/home/athul/Projects/lsp/example.py"
),
```
</details>

<details>
<summary><h3>2. Using Stdio</h3></summary>

This method is easy to start—no terminal setup or extra packages are needed—but it does require a bit more setup in your code. The `LspStdioConfig.start()` method connects to an LSP server using stdio and is asynchronous, so you'll typically use a `FutureBuilder` to handle initialization. It accepts the following parameters:
- `executable`: Location of the LSP server executable file.
- `args`: Arguments to pass to the LSP server executable.
- `filePath`: A filePath is required by the LSP server to provide completions and diagnostics.
- `workspacePath`: The workspace path is the current directory or parent directory which holds the `filePath` file.
- `languageId`: This is a server specific parameter. eg: `'python'` is the language ID used in pyright language server.

To get the `executable` path, you can use the `which` command in the terminal. For example, to get the path of the `basedpyright-langserver`, you can use the following command:

```bash
which basedpyright-langserver
```

#### Example:
Create an async method to initialize the LSP configuration.
```dart
Future<LspConfig?> _initLsp() async {
    try {
      final config = await LspStdioConfig.start(
        executable: '/home/athul/.nvm/versions/node/v20.19.2/bin/basedpyright-langserver',
        args: ['--stdio'],
        workspacePath: '/home/athul/Projects/lsp',
        languageId: 'python',
      );
      
      return config;
    } catch (e) {
      debugPrint('LSP Initialization failed: $e');
      return null;
    }
  }
  ```
  Then use a `FutureBuilder` to initialize the LSP configuration and pass it to the `CodeForgeController` widget:
```dart
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: FutureBuilder(
            future: _initLsp(), // Call the async method to get the LSP config.
            builder: (context, snapshot) {
              if(snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              return CodeForge(
                editorTheme: anOldHopeTheme,
                controller: CodeForgeController(
                  lspConfig: snapshot.data // Pass the config here.
                ),
                filePath: '/home/athul/Projects/lsp/example.py',
                textStyle: TextStyle(fontSize: 15, fontFamily: 'monospace'),
              );
            }
          ),
        ) 
      ),
    );
  }
```
</details>

<hr style="height: 1px; border: none; border-top: 1px">

### Dart LSP Example Using Stdio

```dart
Future<LspConfig> setupDartLsp() async {
  return await LspStdioConfig.start(
    executable: 'dart',
    args: ['language-server', '--protocol=lsp'],
    workspacePath: '/path/to/your/project',
    languageId: 'dart',
  );
}

// In your widget
@override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: FutureBuilder<LspConfig>(
            future: setupDartLsp(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              return CodeForge(
                language: langDart,
                textStyle: GoogleFonts.jetBrainsMono(),
                controller: CodeForgeController(
                  lspConfig: snapshot.data
                ),
                filePath: '/path/to/your/file.dart', // Mandatory field
              )
            },
          ),
        ),
      ),
    );
  }
```
</details>

---

<details>
<summary><h2>🎨 Customization</h2></summary>

CodeForge offers extensive customization options for every aspect of the editor.

### Theme & Styling

```dart
CodeForge(
  controller: controller,
  language: langDart,
  
  // Editor theme (syntax colors)
  editorTheme: vs2015Theme,
  
  // Text styling
  textStyle: GoogleFonts.jetBrainsMono(fontSize: 14),

  // AI Completion styling
  aiCompletionTextStyle: TextStyle(
    color: Colors.grey, // Change the color of the AI completion text
    fontStyle: FontStyle.italic, // Make the AI completion text italic
  ),
  
  // Selection & cursor
  selectionStyle: CodeSelectionStyle(
    cursorColor: Colors.white,
    selectionColor: Colors.blue.withOpacity(0.3),
    cursorBubbleColor: Colors.blue,
  ),
  
  // Gutter (line numbers & fold icons)
  gutterStyle: GutterStyle(
    lineNumberStyle: TextStyle(color: Colors.grey),
    backgroundColor: Color(0xFF1E1E1E),
    activeLineNumberColor: Colors.white,
    foldedIconColor: Colors.grey,
    unfoldedIconColor: Colors.grey,
    errorLineNumberColor: Colors.red,
    warningLineNumberColor: Colors.orange,
  ),
  
  // Suggestion popup
  suggestionStyle: SuggestionStyle(
    backgroundColor: Color(0xFF252526),
    textStyle: TextStyle(color: Colors.white),
    elevation: 8,
  ),
  
  // Hover documentation
  hoverDetailsStyle: HoverDetailsStyle(
    backgroundColor: Color(0xFF252526),
    textStyle: TextStyle(color: Colors.white),
  ),

  // Highlight matching text using [controller.findWord()] and [controller.findRegex()]
  matchHighlightStyle: const MatchHighlightStyle(
    currentMatchStyle: TextStyle(
      backgroundColor: Color(0xFFFFA726),
    ),
    otherMatchStyle: TextStyle(
      backgroundColor: Color(0x55FFFF00),
    ),
  ),
)
```

### Feature Toggles

```dart
CodeForge(
  // Enable/disable features
  enableFolding: true,        // Code folding
  enableGutter: true,         // Line numbers
  enableGuideLines: true,     // Indentation guides
  enableGutterDivider: false, // Gutter separator line
  enableSuggestions: true,    // Autocomplete
  enableKeyboardSuggestions: true // Suggestions from the OS keyboard
  
  // Behavior
  readOnly: false,            // Read-only mode
  autoFocus: true,            // Auto-focus on mount
  lineWrap: false,            // Line wrapping
)
```
</details>

---

<details>
<summary><h2>📚 API Reference</h2></summary>

### CodeForge Widget

| Property | Type | Description |
|----------|------|-------------|
| `controller` | `CodeForgeController?` | Text and selection controller |
| `findController` | `FindController?` | Finder controller for managing search functionality |
| `undoController` | `UndoRedoController?` | Undo/redo history controller |
| `editorTheme` | `Map<String, TextStyle>?` | Syntax color theme |
| `language` | `Mode?` | Syntax highlighting language |
| `focusNode` | `FocusNode?` | Focus node for managing keyboard focus |
| `textStyle` | `TextStyle?` | Base text style |
| `ghostTextStyle` | `TextStyle?` | Text style for ghost text (inline suggestions) |
| `innerPadding` | `EdgeInsets?` | Padding inside the editor content area |
| `verticalScrollController` | `ScrollController?` | Custom scroll controller for vertical scrolling |
| `horizontalScrollController` | `ScrollController?` | Custom scroll controller for horizontal scrolling |
| `selectionStyle` | `CodeSelectionStyle?` | Selection styling |
| `gutterStyle` | `GutterStyle?` | Gutter styling |
| `suggestionStyle` | `SuggestionStyle?` | Suggestion popup styling |
| `hoverDetailsStyle` | `HoverDetailsStyle?` | Hover popup styling |
| `matchHighlightStyle` | `MatchHighlightStyle?` | Highlight the matching words in the controller.findWord() API |
| `filePath` | `String?` | File path for LSP |
| `initialText` | `String?` | Initial editor content |
| `readOnly` | `bool` | Read-only mode |
| `lineWrap` | `bool` | Line wrapping |
| `autoFocus` | `bool` | Auto-focus on mount |
| `enableFolding` | `bool` | Enable code folding |
| `enableGuideLines` | `bool` | Show indentation guides |
| `enableGutter` | `bool` | Show line numbers |
| `enableGutterDivider` | `bool` | Show gutter divider |
| `enableSuggestions` | `bool` | Enable autocomplete suggestions |
| `enableKeyboardSuggestions` | `bool` | Show auto completions in OS virtual keyboard |
| `keyboardType` | `TextInputType` | Type of virtual keyboard |
| `deleteFoldRangeOnDeletingFirstLine` | `bool` | When true, deleting the first line of a folded block removes the entire block |
| `finderBuilder` | `PreferredSizeWidget Function(FindController findController)?` | Builder for custom Finder widget |

### CodeForgeController

```dart
final controller = CodeForgeController();

// Text operations
controller.text = 'Hello, World!';
String content = controller.text;
controller.getLineText(int lineIndex);
controller.insertText(String text, int line, int character);
controller.insertAtCurrentCursor(String text);

// Selection & modification
controller.selection = TextSelection(baseOffset: 0, extentOffset: 5);
controller.selectAll();
controller.copy();
controller.cut();
controller.paste();

// Line operations
int lineCount = controller.lineCount;
String line = controller.getLineText(0);
int lineStart = controller.getLineStartOffset(0);
controller.duplicateLine();
controller.moveLineDown();
controller.moveLineUp();
controller.backspace();
controller.delete();

// Folding
controller.foldAll();
controller.unfoldAll();
controller.toggleFold(lineNumber);

// Search & find
controller.findWord(String word, matchCase: false, matchWholeWord: false);
controller.findRegex(String pattern);
controller.searchHighlights = [
  SearchHighlight(start: 0, end: 5, color: Colors.yellow),
];

// Scroll navigation
controller.scrollToLine(int line);

// Inlay hints
await controller.fetchInlayHints(int startLine, int startCharacter, int endLine, int endCharacter);
controller.showInlayHints();
controller.hideInlayHints();
controller.setInlayHints(List<InlayHint> hints);
controller.clearInlayHints();

// Document colors
await controller.fetchDocumentColors();

// Document highlights
await controller.fetchDocumentHighlights(int line, int character);
controller.clearDocumentHighlights();

// LSP features
await controller.callSignatureHelp();
controller.getCodeAction();

// Editor decorations
controller.setGitDiffDecorations(
  addedRanges: [(int startLine, int endLine), ...],
  removedRanges: [...],
  modifiedRanges: [...],
  addedColor: const Color(0xFF4CAF50),
  removedColor: const Color(0xFFE53935),
  modifiedColor: const Color(0xFF2196F3),
);
controller.clearGitDiffDecorations();

controller.addLineDecoration(LineDecoration decoration);
controller.addLineDecorations(List<LineDecoration> decorations);
controller.removeLineDecoration(String id);
controller.addGutterDecoration(GutterDecoration decoration);
controller.addGutterDecorations(List<GutterDecoration> decorations);
controller.removeGutterDecoration(String id);
controller.clearGutterDecorations();

// Ghost text (inline suggestions)
controller.setGhostText(GhostText ghostText);
controller.clearGhostText();

// File operations
controller.saveFile();

// Navigation
controller.pressLeftArrowKey(isShiftPressed: false);
controller.pressRightArrowKey(isShiftPressed: false);
controller.pressUpArrowKey(isShiftPressed: false);
controller.pressDownArrowKey(isShiftPressed: false);
controller.pressHomeKey(isShiftPressed: false);
controller.pressEndKey(isShiftPressed: false);
controller.pressDocumentHomeKey(isShiftPressed: false);
controller.pressDocumentEndKey(isShiftPressed: false);
controller.pressWordLeftArrowKey(isShiftPressed: false);
controller.pressWordRightArrowKey(isShiftPressed: false);

```
There are more methods available in the CodeForgeController API. You can see the complete list [here](https://pub.dev/documentation/code_forge/latest/code_forge_controller/CodeForgeController-class.html#instance-methods)

### GutterStyle

```dart
GutterStyle({
  TextStyle? lineNumberStyle,
  Color? backgroundColor,
  double? gutterWidth,
  IconData foldedIcon,
  IconData unfoldedIcon,
  double? foldingIconSize,
  Color? foldedIconColor,
  Color? unfoldedIconColor,
  Color? activeLineNumberColor,
  Color? inactiveLineNumberColor,
  Color errorLineNumberColor,
  Color warningLineNumberColor,
  Color? foldedLineHighlightColor,
})
```

### CodeSelectionStyle

```dart
CodeSelectionStyle({
  Color? cursorColor,
  Color selectionColor,
  Color cursorBubbleColor,
})
```

### SuggestionStyle
```dart
SuggestionStyle(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  backgroundColor: Colors.grey[900]!,
  focusColor: Colors.blue.withOpacity(0.3),
  hoverColor: Colors.blue.withOpacity(0.1),
  splashColor: Colors.blue.withOpacity(0.2),
  textStyle: TextStyle(color: Colors.white),
)
```

### HoverDetailsStyle
```dart
HoverDetailsStyle(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  backgroundColor: Colors.grey[850]!,
  focusColor: Colors.blue.withOpacity(0.3),
  hoverColor: Colors.blue.withOpacity(0.1),
  splashColor: Colors.blue.withOpacity(0.2),
  textStyle: TextStyle(color: Colors.white),
)
```

### MatchHighlightStyle
```dart
matchHighlightStyle: const MatchHighlightStyle(
  currentMatchStyle: TextStyle(
    backgroundColor: Color(0xFFFFA726),
  ),
  otherMatchStyle: TextStyle(
    backgroundColor: Color(0x55FFFF00),
  ),
),
```

### LspClientCapabilities

Controls which LSP features are enabled during language server initialization.

```dart
// Pass to LspSocketConfig or LspStdioConfig
final lspConfig = LspSocketConfig(
  workspacePath: "/path/to/workspace",
  languageId: "dart",
  serverUrl: "ws://localhost:5656",
  capabilities: LspClientCapabilities(
    semanticHighlighting: true,  // Semantic token highlighting
    codeCompletion: true,        // Code completion suggestions
    hoverInfo: true,             // Hover documentation
    codeAction: true,            // Code actions and quick fixes
    signatureHelp: true,         // Signature help
    documentColor: true,         // Document color detection
    documentHighlight: true,     // Symbol occurrence highlighting
    codeFolding: true,           // Code folding ranges
    inlayHint: true,             // Inlay hints
    goToDefinition: true,        // Go to definition
    rename: true,                // Symbol renaming
  ),
);
```

</details>

---
<details>
<summary><h2>⌨️ Keyboard Shortcuts</h2></summary>
CodeForge supports a variety of keyboard shortcuts for efficient editing:

### Editing
- **Ctrl+C** — Copy selected text.
- **Ctrl+X** — Cut selected text.
- **Ctrl+V** — Paste text.
- **Ctrl+A** — Select all text.
- **Ctrl+D** — Duplicate current line.
- **Ctrl+Z** — Undo last action.
- **Ctrl+Y** — Redo last action.
- **Ctrl+Backspace** — Delete word backward.
- **Ctrl+Delete** — Delete word forward.

### Navigation
- **Ctrl+Arrow Left** — Move cursor to previous word.
- **Ctrl+Arrow Right** — Move cursor to next word.
- **Ctrl+Shift+Arrow Left** — Select to previous word.
- **Ctrl+Shift+Arrow Right** — Select to next word.
- **Ctrl+Shift+Arrow Up** — Move current line up.
- **Ctrl+Shift+Arrow Down** — Move current line down.

### Indentation
- **Tab** — Indent current line or accept AI completion/suggestion.
- **Shift+Tab** — Unindent current line.

### Suggestions & AI Completion
- **Ctrl+.** — Show available LSP code actions.
- **Ctrl + Shift + Space** — Show available LSP signature help.
- **Ctrl + Alt** — Show LSP inlay hints.
- **Arrow Up/Down** — Navigate through suggestions.
- **Enter/Tab** — Accept current suggestion.
- **Escape** — Close suggestions or hover details.

### Selection
- **Shift+Arrow Keys** — Extend selection.
- **Shift+Home** — Select to line start.
- **Shift+End** — Select to line end.

## Search
- **Ctrl + F** — Show search bar.
- **Ctrl + H** — Show replace bar.

</details>

---

## 🤝 Contributing

Contributions are welcome! Whether it's bug fixes, new features, or documentation improvements.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/heckmon/code_forge/blob/main/LICENSE) file for details.

---

## 🙏 Acknowledgments

- [re_highlight](https://pub.dev/packages/re_highlight) — Syntax highlighting
- [markdown_widget](https://pub.dev/packages/markdown_widget) — Markdown rendering
- [web_socket_channel](https://pub.dev/packages/web_socket_channel) — WebSocket support

---

<p align="center">
  <strong>Built with ❤️ for the Flutter community</strong>
</p>

<p align="center">
  <a href="https://github.com/heckmon/code_forge">
    <img src="https://img.shields.io/badge/⭐_Star_on_GitHub-333333?style=for-the-badge&logo=github" alt="Star on GitHub"/>
  </a>
</p>
