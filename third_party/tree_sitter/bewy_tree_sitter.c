#define BEWY_TS_BUILD_DLL
#include "bewy_tree_sitter.h"
#include "tree-sitter/lib/include/tree_sitter/api.h"

#include <stdlib.h>
#include <string.h>

/* ── Forward-declare all tree_sitter_<lang> functions ────────────────── */
extern const TSLanguage *tree_sitter_c(void);
extern const TSLanguage *tree_sitter_cpp(void);
extern const TSLanguage *tree_sitter_javascript(void);
extern const TSLanguage *tree_sitter_typescript(void);
extern const TSLanguage *tree_sitter_tsx(void);
extern const TSLanguage *tree_sitter_python(void);
extern const TSLanguage *tree_sitter_dart(void);
extern const TSLanguage *tree_sitter_json(void);
extern const TSLanguage *tree_sitter_yaml(void);
extern const TSLanguage *tree_sitter_markdown(void);
extern const TSLanguage *tree_sitter_html(void);
extern const TSLanguage *tree_sitter_xml(void);
extern const TSLanguage *tree_sitter_css(void);

extern const TSLanguage *tree_sitter_java(void);
extern const TSLanguage *tree_sitter_kotlin(void);

extern const TSLanguage *tree_sitter_go(void);
extern const TSLanguage *tree_sitter_rust(void);
extern const TSLanguage *tree_sitter_ruby(void);
extern const TSLanguage *tree_sitter_php(void);
extern const TSLanguage *tree_sitter_lua(void);

extern const TSLanguage *tree_sitter_bash(void);
extern const TSLanguage *tree_sitter_c_sharp(void);
extern const TSLanguage *tree_sitter_r(void);
extern const TSLanguage *tree_sitter_toml(void);
extern const TSLanguage *tree_sitter_powershell(void);
extern const TSLanguage *tree_sitter_dockerfile(void);


/* ── Language lookup table ───────────────────────────────────────────── */
typedef struct {
  const char         *id;
  const TSLanguage *(*fn)(void);
} LangEntry;

static const LangEntry lang_table[] = {
  { "c",          tree_sitter_c },
  { "cpp",        tree_sitter_cpp },
  { "javascript", tree_sitter_javascript },
  { "typescript", tree_sitter_typescript },
  { "tsx",        tree_sitter_tsx },
  { "python",     tree_sitter_python },
  { "dart",       tree_sitter_dart },
  { "json",       tree_sitter_json },
  { "yaml",       tree_sitter_yaml },
  { "markdown",   tree_sitter_markdown },
  { "html",       tree_sitter_html },
  { "xml",        tree_sitter_xml },
  { "css",        tree_sitter_css },
  { "java",       tree_sitter_java },
  { "kotlin",     tree_sitter_kotlin },
  { "go",         tree_sitter_go },
  { "rust",       tree_sitter_rust },
  { "ruby",       tree_sitter_ruby },
  { "php",        tree_sitter_php },
  { "lua",        tree_sitter_lua },
  { "bash",       tree_sitter_bash },
  { "csharp",     tree_sitter_c_sharp },
  { "r",          tree_sitter_r },
  { "toml",       tree_sitter_toml },
  { "powershell", tree_sitter_powershell },
  { "dockerfile", tree_sitter_dockerfile },
};

static const int lang_count = sizeof(lang_table) / sizeof(lang_table[0]);

static const TSLanguage *lookup_language(const char *id) {
  for (int i = 0; i < lang_count; i++) {
    if (strcmp(lang_table[i].id, id) == 0) {
      return lang_table[i].fn();
    }
  }
  return NULL;
}

/* ── Parser handle ───────────────────────────────────────────────────── */
struct BewyTsParser {
  TSParser *parser;
  TSTree   *tree;
};

BEWY_TS_EXPORT BewyTsParser *bewy_ts_parser_new(const char *language_id) {
  if (!language_id) return NULL;
  const TSLanguage *lang = lookup_language(language_id);
  if (!lang) return NULL;

  TSParser *p = ts_parser_new();
  if (!p) return NULL;

  if (!ts_parser_set_language(p, lang)) {
    ts_parser_delete(p);
    return NULL;
  }

  BewyTsParser *handle = (BewyTsParser *)calloc(1, sizeof(BewyTsParser));
  if (!handle) {
    ts_parser_delete(p);
    return NULL;
  }
  handle->parser = p;
  handle->tree   = NULL;
  return handle;
}

/* ── Diagnostic collector ────────────────────────────────────────────── */
typedef struct {
  BewyTsDiagnostic *buf;
  uint32_t          count;
  uint32_t          capacity;
  uint32_t          max;
} DiagCollector;

static void collector_init(DiagCollector *c, uint32_t max) {
  c->buf      = NULL;
  c->count    = 0;
  c->capacity = 0;
  c->max      = max;
}

static int collector_add(DiagCollector *c, BewyTsDiagnostic d) {
  if (c->max > 0 && c->count >= c->max) return 0;
  if (c->count >= c->capacity) {
    uint32_t new_cap = c->capacity == 0 ? 16 : c->capacity * 2;
    BewyTsDiagnostic *tmp = (BewyTsDiagnostic *)realloc(
        c->buf, new_cap * sizeof(BewyTsDiagnostic));
    if (!tmp) return 0;
    c->buf      = tmp;
    c->capacity = new_cap;
  }
  c->buf[c->count++] = d;
  return 1;
}

static void collect_errors(TSNode node, DiagCollector *c) {
  if (c->max > 0 && c->count >= c->max) return;

  if (ts_node_is_error(node)) {
    TSPoint start = ts_node_start_point(node);
    TSPoint end   = ts_node_end_point(node);
    BewyTsDiagnostic d;
    d.start_row = start.row;
    d.start_col = start.column;
    d.end_row   = end.row;
    d.end_col   = end.column;
    d.kind      = 0; /* ERROR */
    collector_add(c, d);
    return; /* Don't recurse into ERROR node children */
  }

  if (ts_node_is_missing(node)) {
    TSPoint start = ts_node_start_point(node);
    TSPoint end   = ts_node_end_point(node);
    BewyTsDiagnostic d;
    d.start_row = start.row;
    d.start_col = start.column;
    d.end_row   = end.row;
    d.end_col   = end.column;
    d.kind      = 1; /* MISSING */
    collector_add(c, d);
    return;
  }

  uint32_t child_count = ts_node_child_count(node);
  for (uint32_t i = 0; i < child_count; i++) {
    /* Quick exit if we've collected enough */
    if (c->max > 0 && c->count >= c->max) return;
    /* Only visit named children that have errors for performance */
    TSNode child = ts_node_child(node, i);
    if (ts_node_is_error(child) || ts_node_is_missing(child) ||
        ts_node_has_error(child)) {
      collect_errors(child, c);
    }
  }
}

/* ── Parse ───────────────────────────────────────────────────────────── */
BEWY_TS_EXPORT uint32_t bewy_ts_parse(
    BewyTsParser      *parser,
    const char        *source,
    uint32_t           source_len,
    uint32_t           max_diagnostics,
    BewyTsDiagnostic **out_items) {
  if (out_items) *out_items = NULL;
  if (!parser || !source || !out_items) return 0;

  /* Always pass NULL for old_tree because the same parser handle is reused
     across different files.  Passing a stale tree would make tree-sitter
     attempt incremental parsing against a mismatched source, which crashes. */
  TSTree *new_tree = ts_parser_parse_string(
      parser->parser, NULL, source, source_len);
  if (parser->tree) {
    ts_tree_delete(parser->tree);
  }
  parser->tree = new_tree;

  if (!new_tree) return 0;

  TSNode root = ts_tree_root_node(new_tree);
  if (!ts_node_has_error(root)) return 0; /* No errors */

  DiagCollector collector;
  collector_init(&collector, max_diagnostics);
  collect_errors(root, &collector);

  *out_items = collector.buf;
  return collector.count;
}

/* ── Free result ─────────────────────────────────────────────────────── */
BEWY_TS_EXPORT void bewy_ts_free_result(BewyTsDiagnostic *items) {
  if (items) {
    free(items);
  }
}

/* ── Free parser ─────────────────────────────────────────────────────── */
BEWY_TS_EXPORT void bewy_ts_parser_free(BewyTsParser *parser) {
  if (!parser) return;
  if (parser->tree) ts_tree_delete(parser->tree);
  if (parser->parser) ts_parser_delete(parser->parser);
  free(parser);
}

/* ── Supported languages ─────────────────────────────────────────────── */
BEWY_TS_EXPORT const char *bewy_ts_supported_languages(void) {
  return
    "c;cpp;javascript;typescript;tsx;python;dart;json;yaml;markdown;"
    "html;xml;css;java;kotlin;go;rust;ruby;php;lua;"
    "bash;csharp;r;toml;powershell;dockerfile";
}
