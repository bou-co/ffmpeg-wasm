#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/aom
CMBUILD_DIR=aom_build

# aom is PINNED + PATCHED for wasm SIMD (see patches/aom-wasm-simd.patch):
# x86-intrinsic kernels compile to wasm simd128 (~1.8x encode speedup,
# byte-identical output); the patch drops nasm-only kernels to C via
# rtcd and stubs inline-x86-asm headers. checkout -f makes this
# idempotent and immune to 'submodule update --remote' moving the tree.
AOM_PIN=03087864cf4bea6abb0d28f95cf7843511413d8f
git -C $LIB_PATH fetch origin $AOM_PIN || true
git -C $LIB_PATH checkout -f $AOM_PIN
git -C $LIB_PATH apply "$(cd "$(dirname $0)/.." && pwd)/patches/aom-wasm-simd.patch"
CM_FLAGS=(
  # common
  -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE        # use emscripten toolchain file
  # wasm-simd: x86 target unlocks the SSE-intrinsic kernels, which
  # emscripten translates to wasm simd128 (runs everywhere incl. ARM);
  # ENABLE_WASM_SIMD gates local aom cmake patches that drop the nasm
  # requirement (asm can't target wasm). x86 (not x86_64) matches
  # wasm32 pointers and excludes the *_x86_64.asm-only kernels.
  -DAOM_TARGET_CPU=x86
  -DENABLE_WASM_SIMD=1
  -DENABLE_SSE4_2=0
  -DENABLE_AVX=0
  -DENABLE_AVX2=1
  -DCONFIG_AV1_HIGHBITDEPTH=0
  -DENABLE_DOCS=0
  -DENABLE_TESTS=0
  -DCONFIG_RUNTIME_CPU_DETECT=0
  -DCONFIG_WEBM_IO=0

  # https://aomedia.googlesource.com/aom/
  #-DENABLE_CCACHE=1
  #-DCONFIG_ACCOUNTING=1
  #-DCONFIG_INSPECTION=1
  #-DCONFIG_MULTITHREAD=0

  # https://github.com/ffmpegwasm/ffmpeg.wasm-core/blob/n4.3.1-wasm/wasm/build-scripts/build-aom.sh
  -DCMAKE_INSTALL_PREFIX=$BUILD_DIR             # assign lib and include install path
  -DBUILD_SHARED_LIBS=0                         # disable shared library build
  -DENABLE_EXAMPLES=0                           # disable examples
  -DENABLE_TOOLS=0                              # disable tools

  # https://github.com/xiph/aomanalyzer/issues/81
  -DCMAKE_BUILD_TYPE=Release
)

echo "CM_FLAGS=${CM_FLAGS[@]}"

rm -rf $LIB_PATH/CMakeCache.txt
rm -rf $LIB_PATH/CMakeFiles
rm -rf $LIB_PATH/$CMBUILD_DIR
mkdir -p $LIB_PATH/$CMBUILD_DIR

(cd $LIB_PATH/$CMBUILD_DIR && emmake cmake .. ${CM_FLAGS[@]} \
  -DAOM_EXTRA_C_FLAGS="$CFLAGS" \
  -DAOM_EXTRA_CXX_FLAGS="$CXXFLAGS" \
  -G"Unix Makefiles")
emmake make -C $LIB_PATH/$CMBUILD_DIR clean
emmake make -C $LIB_PATH/$CMBUILD_DIR install -j$(nproc)
