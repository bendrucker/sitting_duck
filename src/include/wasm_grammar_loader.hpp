#pragma once

#include "duckdb.hpp"
#include <tree_sitter/api.h>

namespace duckdb {

// Loads tree-sitter grammars from .wasm modules for register_language().
// Mirrors DynamicLibraryLoader's lifetime policy: the wasmtime engine, the
// registration-time wasm store, and every loaded TSLanguage live for the
// process lifetime, because adapters and in-flight parses hold raw pointers.
//
// Real implementation only when the build enables tree-sitter's wasm feature
// (SITTING_DUCK_WASM_GRAMMARS); otherwise every method throws
// NotImplementedException.
class WasmGrammarLoader {
public:
	// Compile and instantiate wasm grammar bytes, returning the language the
	// module exports as tree_sitter_<load_name>. Throws InvalidInputException
	// carrying the TSWasmError message on failure, naming `path`.
	static const TSLanguage *LoadLanguageFromBytes(const string &load_name, const string &bytes, const string &path);

	// Create a wasm store for a parser about to use a wasm-backed language.
	// Stores are single-parser, but all share one process-global engine, so
	// languages loaded at registration time work with any of them. The parser
	// takes ownership (ts_parser_delete frees an attached store).
	static TSWasmStore *CreateParserStore();
};

} // namespace duckdb
