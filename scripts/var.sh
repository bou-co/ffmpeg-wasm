#!/bin/bash

set -euo pipefail

# Include llvm binaries
export PATH=$PATH:$EMSDK/upstream/bin

ROOT_DIR=$PWD

# The repo-local venv supplies pkgconf (as pkg-config), cmake, meson and
# ninja. Nothing here is guaranteed to exist system-wide -- this host has
# neither cmake nor pkg-config installed, and ffmpeg's configure fails at
# "aom >= 2.0.0 not found using pkg-config" without it. build-dav1d.sh
# already did this for meson; doing it here covers every script.
if [ -d "$ROOT_DIR/.toolvenv/bin" ]; then
    export PATH="$ROOT_DIR/.toolvenv/bin:$PATH"
fi
WASM_DIR=$ROOT_DIR/wasm

# FFMPEG_WASM64=true builds the memory64 engine (ffmpeg-gpl-mem64), whose
# heap can grow past the 4 GiB wasm32 ceiling. Every library has to be
# compiled with -m64 as well, so the variant gets its own install prefix
# (build64) and the wasm32 libraries in build/ are left untouched.
FFMPEG_WASM64=${FFMPEG_WASM64:-false}
if [ "$FFMPEG_WASM64" = true ] ; then
    BUILD_DIR=$ROOT_DIR/build64
    WASM_ARCH=wasm64
else
    BUILD_DIR=$ROOT_DIR/build
    WASM_ARCH=wasm32
fi
EM_PKG_CONFIG_PATH=$BUILD_DIR/lib/pkgconfig
TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

# `-Og` -> no optimization
# `-g` -> debug info enabled
CFLAGS="-O3 -flto -I$BUILD_DIR/include -pthread -msimd128 -mavx2"
if [ "$FFMPEG_WASM64" = true ] ; then
    CFLAGS="$CFLAGS -m64"
fi

OUTPUT_FILENAME="ffmpeg"
if [ "$FFMPEG_LGPL" = true ] ; then
    OUTPUT_FILENAME="$OUTPUT_FILENAME-lgpl"
else
    OUTPUT_FILENAME="$OUTPUT_FILENAME-gpl"
fi
if [ "$FFMPEG_WASM64" = true ] ; then
    OUTPUT_FILENAME="$OUTPUT_FILENAME-mem64"
fi
OUTPUT_PATH=$WASM_DIR/$OUTPUT_FILENAME.js
OUTPUT_PATH_WV=$WASM_DIR/$OUTPUT_FILENAME-wv.js

export CFLAGS=$CFLAGS
export CXXFLAGS=$CFLAGS
export LDFLAGS="$CFLAGS -L$BUILD_DIR/lib"
export EM_PKG_CONFIG_PATH=$EM_PKG_CONFIG_PATH

echo "EMSDK=$EMSDK"
echo "CFLAGS=$CFLAGS"
echo "CXXFLAGS=$CXXFLAGS"
echo "LDFLAGS=$LDFLAGS"
echo "BUILD_DIR=$BUILD_DIR"
