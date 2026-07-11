#include "wasm_grammar_loader.hpp"
#include "duckdb/common/exception.hpp"

#ifdef TREE_SITTER_FEATURE_WASM

#include <cstdlib>
#include <mutex>
#include <wasm.h>

namespace duckdb {

// Takes ownership of the malloc'd TSWasmError message
static string ConsumeWasmError(TSWasmError &error) {
	if (!error.message) {
		return "unknown wasm error";
	}
	string message(error.message);
	std::free(error.message);
	return message;
}

static TSWasmEngine *GetEngine() {
	static TSWasmEngine *engine = wasm_engine_new();
	if (!engine) {
		throw InternalException("Failed to create wasm engine for grammar loading");
	}
	return engine;
}

const TSLanguage *WasmGrammarLoader::LoadLanguageFromBytes(const string &load_name, const string &bytes,
                                                           const string &path) {
	// One store handles all registrations. Stores are single-parser, so it must
	// not be shared with query execution, and registration is rare enough that
	// serializing loads behind a mutex costs nothing.
	static std::mutex registration_mutex;
	static TSWasmStore *registration_store = nullptr;

	std::lock_guard<std::mutex> guard(registration_mutex);
	TSWasmError error {};
	if (!registration_store) {
		registration_store = ts_wasm_store_new(GetEngine(), &error);
		if (!registration_store) {
			throw InternalException("Failed to create wasm store: %s", ConsumeWasmError(error));
		}
	}
	const TSLanguage *language = ts_wasm_store_load_language(registration_store, load_name.c_str(), bytes.data(),
	                                                         static_cast<uint32_t>(bytes.size()), &error);
	if (!language) {
		throw InvalidInputException("Failed to load WASM grammar '%s': %s", path, ConsumeWasmError(error));
	}
	return language;
}

TSWasmStore *WasmGrammarLoader::CreateParserStore() {
	TSWasmError error {};
	TSWasmStore *store = ts_wasm_store_new(GetEngine(), &error);
	if (!store) {
		throw InternalException("Failed to create wasm store: %s", ConsumeWasmError(error));
	}
	return store;
}

} // namespace duckdb

#else

namespace duckdb {

const TSLanguage *WasmGrammarLoader::LoadLanguageFromBytes(const string &load_name, const string &bytes,
                                                           const string &path) {
	throw NotImplementedException("register_language: this build does not support WASM grammars "
	                              "(built with SITTING_DUCK_WASM_GRAMMARS=OFF or targeting WASM)");
}

TSWasmStore *WasmGrammarLoader::CreateParserStore() {
	throw NotImplementedException("register_language: this build does not support WASM grammars "
	                              "(built with SITTING_DUCK_WASM_GRAMMARS=OFF or targeting WASM)");
}

} // namespace duckdb

#endif
