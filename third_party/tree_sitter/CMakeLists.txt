cmake_minimum_required(VERSION 3.14)
project(bewy_tree_sitter C CXX)

# ── Tree-sitter runtime ─────────────────────────────────────────────────
set(TS_RUNTIME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/tree-sitter/lib")

# tree-sitter runtime: lib.c includes all other .c files via #include
# so we only compile lib.c to avoid duplicate symbols.
set(TS_RUNTIME_SOURCES "${TS_RUNTIME_DIR}/src/lib.c")

# ── Grammar sources ─────────────────────────────────────────────────────
set(GRAMMAR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/grammars")

# Simple grammars: grammars/<lang>/parser.c [+ scanner.c/cc]
set(SIMPLE_GRAMMAR_LANGS
  c cpp javascript python dart json yaml markdown
  html css java kotlin go rust ruby lua
  bash csharp r toml powershell dockerfile
)

set(GRAMMAR_SOURCES "")
set(GRAMMAR_SCANNER_CXX_SOURCES "")
set(GRAMMAR_INCLUDE_DIRS "")

foreach(LANG ${SIMPLE_GRAMMAR_LANGS})
  set(PARSER_C "${GRAMMAR_DIR}/${LANG}/parser.c")
  if(EXISTS "${PARSER_C}")
    list(APPEND GRAMMAR_SOURCES "${PARSER_C}")
  else()
    message(WARNING "Grammar parser.c not found for ${LANG}: ${PARSER_C}")
  endif()

  set(SCANNER_C "${GRAMMAR_DIR}/${LANG}/scanner.c")
  set(SCANNER_CC "${GRAMMAR_DIR}/${LANG}/scanner.cc")
  if(EXISTS "${SCANNER_C}")
    list(APPEND GRAMMAR_SOURCES "${SCANNER_C}")
  elseif(EXISTS "${SCANNER_CC}")
    list(APPEND GRAMMAR_SCANNER_CXX_SOURCES "${SCANNER_CC}")
  endif()

  list(APPEND GRAMMAR_INCLUDE_DIRS "${GRAMMAR_DIR}/${LANG}")
endforeach()

# ── Restructured grammars (with common/ directory) ───────────────────────
# TypeScript / TSX: grammars/typescript_repo/{common,typescript/src,tsx/src}
set(TS_REPO "${GRAMMAR_DIR}/typescript_repo")
list(APPEND GRAMMAR_SOURCES
  "${TS_REPO}/typescript/src/parser.c"
  "${TS_REPO}/typescript/src/scanner.c"
  "${TS_REPO}/tsx/src/parser.c"
  "${TS_REPO}/tsx/src/scanner.c"
)
list(APPEND GRAMMAR_INCLUDE_DIRS
  "${TS_REPO}/typescript/src"
  "${TS_REPO}/tsx/src"
)

# XML: grammars/xml_repo/{common,xml/src}
set(XML_REPO "${GRAMMAR_DIR}/xml_repo")
list(APPEND GRAMMAR_SOURCES
  "${XML_REPO}/xml/src/parser.c"
  "${XML_REPO}/xml/src/scanner.c"
)
list(APPEND GRAMMAR_INCLUDE_DIRS "${XML_REPO}/xml/src")

# PHP: grammars/php_repo/{common,php/src}
set(PHP_REPO "${GRAMMAR_DIR}/php_repo")
list(APPEND GRAMMAR_SOURCES
  "${PHP_REPO}/php/src/parser.c"
  "${PHP_REPO}/php/src/scanner.c"
)
list(APPEND GRAMMAR_INCLUDE_DIRS "${PHP_REPO}/php/src")

# ── Build shared library ────────────────────────────────────────────────
add_library(bewy_tree_sitter SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/bewy_tree_sitter.c"
  ${TS_RUNTIME_SOURCES}
  ${GRAMMAR_SOURCES}
  ${GRAMMAR_SCANNER_CXX_SOURCES}
)

target_compile_definitions(bewy_tree_sitter PRIVATE BEWY_TS_BUILD_DLL)

target_include_directories(bewy_tree_sitter PRIVATE
  "${TS_RUNTIME_DIR}/include"
  "${TS_RUNTIME_DIR}/src"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  ${GRAMMAR_INCLUDE_DIRS}
)

# Suppress warnings in third-party code
if(MSVC)
  target_compile_options(bewy_tree_sitter PRIVATE /W0)
else()
  target_compile_options(bewy_tree_sitter PRIVATE -w)
endif()

# C++14 for scanner.cc files
set_target_properties(bewy_tree_sitter PROPERTIES
  CXX_STANDARD 14
  CXX_STANDARD_REQUIRED OFF
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)

# Output name
set_target_properties(bewy_tree_sitter PROPERTIES
  OUTPUT_NAME "bewy_tree_sitter"
)
