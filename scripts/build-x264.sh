#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/x264

# x264 is PINNED: newer wide.video revisions trap with
# 'RuntimeError: function signature mismatch' at pthread entry in wasm
# (any multithreaded h264 encode). Enforced here because modules/ is
# gitignored and 'submodule update --remote' would move the checkout.
# Do not bump without re-verifying multithreaded h264 in the browser.
X264_PIN=64f6a907b60fed93b49285a6cd19a90d1f0d009c
git -C $LIB_PATH fetch origin $X264_PIN || true
git -C $LIB_PATH checkout $X264_PIN
CONF_FLAGS=(
  --prefix=$BUILD_DIR           # install library in a build directory for FFmpeg to include
  --host=i686-gnu               # use i686 linux
  --enable-static               # enable building static library
  --disable-cli                 # disable cli tools
  --disable-asm                 # disable asm optimization
  --extra-cflags="$CFLAGS"      # flags to use pthread and code optimization
)
echo "CONF_FLAGS=${CONF_FLAGS[@]}"
(cd $LIB_PATH && emconfigure ./configure "${CONF_FLAGS[@]}")
emmake make -C $LIB_PATH clean
emmake make -C $LIB_PATH lib-static -j$(nproc)
emmake make -C $LIB_PATH install-lib-static
