#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/libvpx

CONF_FLAGS=(
  --prefix=$BUILD_DIR                                # install library in a build directory for FFmpeg to include
  --target=generic-gnu                               # target with miminal features
  --disable-install-bins                             # not to install bins
  --disable-examples                                 # not to build examples
  --disable-tools                                    # not to build tools
  --disable-docs                                     # not to build docs
  --disable-unit-tests                               # not to do unit tests
  --disable-dependency-tracking                      # speed up one-time build
  --disable-shared
  --disable-codec-srcs
  --disable-debug-libs
  --disable-runtime-cpu-detect                       # make sure libvpx’s configure doesn’t disable SIMD
  --enable-multithread                               # not sure if needed, but seen used around the internets

  # The app only ENCODES vp9, and only 8-bit yuva420p (Edit mode's
  # transparent WebM export): ffmpeg's native vp9 decoder handles every
  # upload, so the decoders, vp8 and the high-bit-depth paths are dead
  # weight in the wasm.
  --disable-vp8
  --disable-vp9-decoder
  --disable-vp9-highbitdepth

  # https://github.com/emscripten-core/emscripten/issues/22524
  # disables `-flto`
  --extra-cflags="$CFLAGS -fno-lto"
  --extra-cxxflags="$CXXFLAGS -fno-lto"
)
echo "CONF_FLAGS=${CONF_FLAGS[@]}"
(cd $LIB_PATH && emconfigure ./configure "${CONF_FLAGS[@]}")
emmake make -C $LIB_PATH clean
emmake make -C $LIB_PATH install STRIP=emstrip -j$(nproc)
