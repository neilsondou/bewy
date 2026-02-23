# LSP Diagnostics Demo

Open these files in Bewy to verify LSP diagnostics.
Each file intentionally contains obvious syntax errors.

## Files

| File | Language | Errors |
|------|----------|--------|
| `broken.dart` | Dart | type mismatch, undefined variable, unclosed bracket |
| `broken.js` | JavaScript | unexpected token, unclosed bracket, undefined variable |
| `broken.ts` | TypeScript | type mismatches, undefined symbol |
| `broken.py` | Python | type mismatch, undefined variable, missing colon |
| `broken.json` | JSON | trailing comma, missing comma |
| `broken.yaml` | YAML | bad indentation (multiple) |
| `broken.yml` | YAML | bad indentation, mixing sequence/mapping |
| `broken.md` | Markdown | broken link, unclosed bold, unclosed image |
| `broken.c` | C | missing initializer, undeclared identifier, missing semicolon |
| `broken.cpp` | C++ | type mismatch, undeclared identifier, missing semicolon |
| `broken.h` | C Header | missing semicolon, invalid array syntax, bad declaration |
| `broken.hpp` | C++ Header | missing paren, missing semicolon on member |
| `broken.jsx` | JSX | missing expression, unclosed tag, invalid JSX expression |
| `broken.tsx` | TSX | type mismatch, nonexistent property, unclosed tag |
| `broken.swift` | Swift | type mismatch, unclosed bracket, undefined variable |
| `broken.kt` | Kotlin | type mismatch, unresolved reference, unclosed paren |
| `broken.java` | Java | type mismatch, undefined symbol, missing semicolon |
| `broken.go` | Go | type mismatch, undefined variable, unused variable |
| `broken.rs` | Rust | type mismatches, undefined variable, unclosed bracket |
| `broken.rb` | Ruby | missing `end` keywords |
| `broken.xml` | XML | mismatched tag case, unclosed tags |
| `broken.html` | HTML | mismatched closing tags, unclosed elements |
| `broken.css` | CSS | missing semicolons, invalid value, unclosed brace |
| `broken.scss` | SCSS | missing semicolons, empty value, undefined variable |
| `broken.toml` | TOML | wrong value type, unclosed brace, unquoted string |
| `broken.ini` | INI | empty value, unclosed section, bad indentation |
| `broken.php` | PHP | missing semicolons, undefined variable, missing paren |
| `broken.lua` | Lua | missing `end`, unclosed table, missing `end` for if |
| `broken.sql` | SQL | keyword typos, unclosed parentheses |
| `broken.ps1` | PowerShell | unclosed function, unclosed paren, missing paren |
| `broken.sh` | Shell | missing closing brace, missing `fi`, missing `done` |
