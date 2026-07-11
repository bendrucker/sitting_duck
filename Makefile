PROJ_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Configuration of extension
EXT_NAME=duckdb_ast
EXT_CONFIG=${PROJ_DIR}extension_config.cmake

# Include the Makefile from extension-ci-tools
include extension-ci-tools/makefiles/duckdb_extension.Makefile

############################
# Parser Generation Targets
############################
# These targets manage pre-generated tree-sitter parsers, allowing builds
# without tree-sitter CLI, Node.js, or Cargo dependencies.

.PHONY: generate-parsers clean-parsers regenerate-parsers

# Generate all tree-sitter parsers and store in generated_parsers/
# Requires: tree-sitter CLI, Node.js
generate-parsers:
	@echo "Generating tree-sitter parsers..."
	chmod +x scripts/generate_all_parsers.sh
	./scripts/generate_all_parsers.sh

# Clean the generated parsers directory
clean-parsers:
	@echo "Cleaning generated parsers..."
	rm -rf generated_parsers

# Regenerate parsers (clean first, then generate)
regenerate-parsers: clean-parsers generate-parsers

############################
# Dynamic Grammar Test Library
############################
# Builds a standalone tree-sitter grammar shared library from the pre-generated
# JSON parser. Used by test/sql/dynamic_languages/ to exercise register_language().
# The library is named .so on all platforms: dlopen() ignores the suffix, and a
# uniform name keeps the sqllogictests platform-independent.
# Run the dynamic language tests with:
#   make test-grammar-lib test-grammar-wasm
#   SITTING_DUCK_TEST_GRAMMAR_DIR=build/test_grammars \
#     SITTING_DUCK_TEST_GRAMMAR_WASM_DIR=build/test_grammars make test
# Builds configured with -DSITTING_DUCK_WASM_GRAMMARS=OFF should leave
# SITTING_DUCK_TEST_GRAMMAR_WASM_DIR unset so the wasm tests skip.

TEST_GRAMMAR_DIR := build/test_grammars

.PHONY: test-grammar-lib
test-grammar-lib:
	mkdir -p $(TEST_GRAMMAR_DIR)
	cc -shared -fPIC -O2 \
		-I generated_parsers/tree-sitter-json/src \
		generated_parsers/tree-sitter-json/src/parser.c \
		-o $(TEST_GRAMMAR_DIR)/libjson_dyn.so

# Fetches a release-built JSON grammar .wasm (pinned by SHA256) and derives the
# invalid-input fixtures used by register_language_wasm.test. Building the .wasm
# locally would require emscripten. The release artifact is the same thing users
# will register, which is exactly what the tests should exercise.
TEST_GRAMMAR_WASM_URL := https://github.com/tree-sitter/tree-sitter-json/releases/download/v0.24.8/tree-sitter-json.wasm
TEST_GRAMMAR_WASM_SHA256 := d2119fb98d5912719b13f9458574f8608d2d29dfbe45f6be1f860ea1fe2a2405

.PHONY: test-grammar-wasm
test-grammar-wasm:
	mkdir -p $(TEST_GRAMMAR_DIR)
	curl -fsSL -o $(TEST_GRAMMAR_DIR)/json_grammar.wasm "$(TEST_GRAMMAR_WASM_URL)"
	printf '%s  %s\n' "$(TEST_GRAMMAR_WASM_SHA256)" "$(TEST_GRAMMAR_DIR)/json_grammar.wasm" > $(TEST_GRAMMAR_DIR)/json_grammar.wasm.sha256
	@if command -v sha256sum >/dev/null 2>&1; then sha256sum -c $(TEST_GRAMMAR_DIR)/json_grammar.wasm.sha256; \
	else shasum -a 256 -c $(TEST_GRAMMAR_DIR)/json_grammar.wasm.sha256; fi
	head -c 96 $(TEST_GRAMMAR_DIR)/json_grammar.wasm > $(TEST_GRAMMAR_DIR)/truncated.wasm
	printf '\0asm\1\0\0\0not a real module' > $(TEST_GRAMMAR_DIR)/garbage.wasm

############################
# Format Target Overrides
############################
# Override format targets from extension-ci-tools to exclude test/data/.
# Test data files are parsed as AST fixtures with exact line numbers and node
# counts asserted in tests. Formatting them shifts lines and adds nodes,
# breaking those assertions.

FORMAT_DIRS := src test/sql test/unittest

format-check:
	python3 duckdb/scripts/format.py --all --check --directories $(FORMAT_DIRS)

format:
	python3 duckdb/scripts/format.py --all --fix --noconfirm --directories $(FORMAT_DIRS)

format-fix:
	python3 duckdb/scripts/format.py --all --fix --noconfirm --directories $(FORMAT_DIRS)

format-main:
	python3 duckdb/scripts/format.py main --fix --noconfirm --directories $(FORMAT_DIRS)