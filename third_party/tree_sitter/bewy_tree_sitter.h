#ifndef BEWY_TREE_SITTER_H
#define BEWY_TREE_SITTER_H

#ifdef _WIN32
#  ifdef BEWY_TS_BUILD_DLL
#    define BEWY_TS_EXPORT __declspec(dllexport)
#  else
#    define BEWY_TS_EXPORT __declspec(dllimport)
#  endif
#else
#  define BEWY_TS_EXPORT __attribute__((visibility("default")))
#endif

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle returned by bewy_ts_parser_new. */
typedef struct BewyTsParser BewyTsParser;

/* A single diagnostic node (ERROR or MISSING). */
typedef struct {
  uint32_t start_row;
  uint32_t start_col;
  uint32_t end_row;
  uint32_t end_col;
  uint32_t kind;   /* 0 = ERROR, 1 = MISSING */
} BewyTsDiagnostic;

/*
 * Create a parser for the given language_id string.
 * Returns NULL if the language is not supported.
 * The caller must free the parser with bewy_ts_parser_free().
 */
BEWY_TS_EXPORT BewyTsParser *bewy_ts_parser_new(const char *language_id);

/*
 * Parse the given UTF-8 source text and collect ERROR/MISSING nodes.
 * `max_diagnostics` limits the number of diagnostics collected (0 = no limit).
 * On success, *out_items is set to a malloc'd array and the return value is
 * the number of diagnostics.  The caller must free *out_items with
 * bewy_ts_free_result().  If there are no errors, *out_items is set to NULL
 * and 0 is returned.
 */
BEWY_TS_EXPORT uint32_t bewy_ts_parse(
    BewyTsParser      *parser,
    const char        *source,
    uint32_t           source_len,
    uint32_t           max_diagnostics,
    BewyTsDiagnostic **out_items);

/*
 * Free a diagnostic items array previously returned via out_items.
 */
BEWY_TS_EXPORT void bewy_ts_free_result(BewyTsDiagnostic *items);

/*
 * Free a parser and its associated tree.
 */
BEWY_TS_EXPORT void bewy_ts_parser_free(BewyTsParser *parser);

/*
 * Return a semicolon-separated list of supported language IDs.
 * The returned string is statically allocated and must NOT be freed.
 */
BEWY_TS_EXPORT const char *bewy_ts_supported_languages(void);

#ifdef __cplusplus
}
#endif

#endif /* BEWY_TREE_SITTER_H */
