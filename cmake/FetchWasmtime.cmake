# Fetches the prebuilt wasmtime C API for the current platform and points the
# tree-sitter subdirectory's wasm feature at it (WASMTIME_INCLUDE_DIR and
# WASMTIME_LIBRARY cache variables). Runs at configure time so no network
# access happens during the build itself.
#
# Providing both cache variables yourself skips the download entirely.

# Pinned to the wasmtime C API generation the vendored tree-sitter targets
# (its Cargo.lock pins wasmtime 29.x). Later wasmtime releases changed the
# layout of wasmtime_func_t, which wasm_store.c relies on, so bump this
# version and third_party/tree-sitter together.
set(WASMTIME_VERSION "v29.0.1")

# Values inside our managed wasmtime-c-api directory are cache leftovers from
# an earlier configure, possibly of a different pinned version. Re-derive those.
if(WASMTIME_INCLUDE_DIR AND WASMTIME_LIBRARY AND NOT WASMTIME_LIBRARY MATCHES "/wasmtime-c-api/")
    message(STATUS "Using provided wasmtime: ${WASMTIME_LIBRARY}")
    return()
endif()

# Map CMAKE_SYSTEM_NAME/CMAKE_SYSTEM_PROCESSOR onto a wasmtime release asset.
# SHA256 values are pinned from the ${WASMTIME_VERSION} release.
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
        set(WASMTIME_PLATFORM "aarch64-macos")
        set(WASMTIME_SHA256 "3aa840ba24f14107bc7dd9b82b1b7b31ece8ea472e06820251ac76cafa8722c0")
    else()
        set(WASMTIME_PLATFORM "x86_64-macos")
        set(WASMTIME_SHA256 "24fbf0845402437c5857b99d78583177a85a025c91d99a937c1e2c11ec09fcad")
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # musl targets need the musl-linked wasmtime build
    execute_process(COMMAND ${CMAKE_C_COMPILER} -dumpmachine
                    OUTPUT_VARIABLE WASMTIME_C_TRIPLE
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
        if(WASMTIME_C_TRIPLE MATCHES "musl")
            set(WASMTIME_PLATFORM "aarch64-musl")
            set(WASMTIME_SHA256 "fdf053a4bbf28f4b8de4c92264e4417169abdd6760e293f9815ed7b0e7ebdaf9")
        else()
            set(WASMTIME_PLATFORM "aarch64-linux")
            set(WASMTIME_SHA256 "7ab76595f765d60ba14c498ec25506e519213c4ba783f52a7bec5370b09ace6d")
        endif()
    else()
        if(WASMTIME_C_TRIPLE MATCHES "musl")
            set(WASMTIME_PLATFORM "x86_64-musl")
            set(WASMTIME_SHA256 "20f12b08e5ab564cf78aec02bffb154def8069d3b8654e04f94a31926cb9096f")
        else()
            set(WASMTIME_PLATFORM "x86_64-linux")
            set(WASMTIME_SHA256 "27871520e02193badd5a83e16a5009c45371ec5ec9e1df8342b4a17efc3e35b6")
        endif()
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|aarch64)$")
        set(WASMTIME_PLATFORM "aarch64-windows")
        set(WASMTIME_SHA256 "e8e4ebb4720889dfe7b7f0eddd0b98151e6cabecb3aed12d1898e2a973188607")
    elseif(MINGW)
        set(WASMTIME_PLATFORM "x86_64-mingw")
        set(WASMTIME_SHA256 "8371821d3da010417a686e7401459edbb54a32a388ed12aac64d412414625826")
    else()
        set(WASMTIME_PLATFORM "x86_64-windows")
        set(WASMTIME_SHA256 "c5d85f7d912f8d2ab80a0d875398e3601de0e4e32c0d5370e2a67dc89fb0625f")
    endif()
else()
    message(FATAL_ERROR
        "No prebuilt wasmtime mapping for ${CMAKE_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}.\n"
        "Either build with -DSITTING_DUCK_WASM_GRAMMARS=OFF or provide "
        "-DWASMTIME_INCLUDE_DIR=... and -DWASMTIME_LIBRARY=... yourself.")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(WASMTIME_ARCHIVE_EXT "zip")
else()
    set(WASMTIME_ARCHIVE_EXT "tar.xz")
endif()

set(WASMTIME_ASSET "wasmtime-${WASMTIME_VERSION}-${WASMTIME_PLATFORM}-c-api")
set(WASMTIME_URL "https://github.com/bytecodealliance/wasmtime/releases/download/${WASMTIME_VERSION}/${WASMTIME_ASSET}.${WASMTIME_ARCHIVE_EXT}")
set(WASMTIME_ROOT "${CMAKE_BINARY_DIR}/wasmtime-c-api/${WASMTIME_ASSET}")

if(NOT EXISTS "${WASMTIME_ROOT}/include/wasmtime.h")
    set(WASMTIME_ARCHIVE "${CMAKE_BINARY_DIR}/wasmtime-c-api/${WASMTIME_ASSET}.${WASMTIME_ARCHIVE_EXT}")
    message(STATUS "Fetching wasmtime C API: ${WASMTIME_URL}")
    file(DOWNLOAD "${WASMTIME_URL}" "${WASMTIME_ARCHIVE}"
         EXPECTED_HASH SHA256=${WASMTIME_SHA256}
         STATUS WASMTIME_DOWNLOAD_STATUS)
    list(GET WASMTIME_DOWNLOAD_STATUS 0 WASMTIME_DOWNLOAD_CODE)
    if(NOT WASMTIME_DOWNLOAD_CODE EQUAL 0)
        list(GET WASMTIME_DOWNLOAD_STATUS 1 WASMTIME_DOWNLOAD_ERROR)
        message(FATAL_ERROR "Failed to download wasmtime: ${WASMTIME_DOWNLOAD_ERROR}\n"
                            "Build with -DSITTING_DUCK_WASM_GRAMMARS=OFF to skip wasm grammar support.")
    endif()
    file(ARCHIVE_EXTRACT INPUT "${WASMTIME_ARCHIVE}"
         DESTINATION "${CMAKE_BINARY_DIR}/wasmtime-c-api")
    file(REMOVE "${WASMTIME_ARCHIVE}")
endif()

if(MSVC)
    set(WASMTIME_STATIC_LIB "${WASMTIME_ROOT}/lib/wasmtime.lib")
else()
    set(WASMTIME_STATIC_LIB "${WASMTIME_ROOT}/lib/libwasmtime.a")
endif()

set(WASMTIME_INCLUDE_DIR "${WASMTIME_ROOT}/include" CACHE PATH "wasmtime C API headers" FORCE)
set(WASMTIME_LIBRARY "${WASMTIME_STATIC_LIB}" CACHE FILEPATH "wasmtime static library" FORCE)
message(STATUS "wasmtime C API ready: ${WASMTIME_LIBRARY}")
