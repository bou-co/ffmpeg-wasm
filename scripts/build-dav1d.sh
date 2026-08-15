#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/dav1d
MESON_BUILD_DIR=dav1d_build

# dav1d (BSD-2) — AV1 DECODER. ffmpeg auto-prefers libdav1d over
# libaom for av1 decode, which matters here: the libaom wasm DECODER
# hangs/crashes at >=1080p (verified 2026-08-15; encoder unaffected).
# asm is nasm/gas-only so it can't target wasm — the C paths compile
# to wasm simd via CFLAGS and are plenty for preview/poster decode.
DAV1D_PIN=1.5.4
git -C $LIB_PATH fetch origin --tags || true
git -C $LIB_PATH checkout -f $DAV1D_PIN

# dav1d needs meson+ninja. Docker: apt-get install -y meson ninja-build
# (add to docker-init.sh when containerized builds resume). Host: the
# repo-local venv created for this purpose.
if [ -d "$ROOT_DIR/.toolvenv/bin" ]; then
    export PATH="$ROOT_DIR/.toolvenv/bin:$PATH"
fi

# meson ignores env CFLAGS in cross builds — inject them via the cross
# file as a meson string array
MESON_C_ARGS=$(printf "'%s', " $CFLAGS)
MESON_C_ARGS=${MESON_C_ARGS%, }

CROSS_FILE=$LIB_PATH/emscripten-cross.ini
cat > $CROSS_FILE <<EOF
[binaries]
c = 'emcc'
cpp = 'em++'
ar = 'emar'
nm = 'emnm'
strip = '$EMSDK/upstream/bin/llvm-strip'

[built-in options]
c_args = [$MESON_C_ARGS]
c_link_args = [$MESON_C_ARGS]

[host_machine]
system = 'emscripten'
cpu_family = 'wasm32'
cpu = 'wasm32'
endian = 'little'
EOF

rm -rf $LIB_PATH/$MESON_BUILD_DIR
meson setup $LIB_PATH/$MESON_BUILD_DIR $LIB_PATH \
    --cross-file $CROSS_FILE \
    --prefix $BUILD_DIR \
    --libdir lib \
    --default-library static \
    --buildtype release \
    -Denable_asm=false \
    -Denable_tools=false \
    -Denable_tests=false \
    -Denable_examples=false \
    -Dlogging=false

ninja -C $LIB_PATH/$MESON_BUILD_DIR install
