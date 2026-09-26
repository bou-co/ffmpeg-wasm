#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/zimg
CONF_FLAGS=(
  --prefix=$BUILD_DIR              # lib installation directory
  --host=wasm32-unknown-emscripten
  --disable-shared                 # build static library
  --disable-tools                  # CMD line utils
  --enable-static                  # enable static library
  --enable-avx512
)
echo "CONF_FLAGS=${CONF_FLAGS[@]}"
# autogen.sh needs autoreconf (autoconf/automake/libtool), which this host
# lacks; a configure script it generated earlier works just as well
if command -v autoreconf >/dev/null || [ ! -x $LIB_PATH/configure ] ; then
  (cd $LIB_PATH && emconfigure ./autogen.sh)
fi
(cd $LIB_PATH && \
  CFLAGS=$CFLAGS LDFLAGS=$LDFLAGS emconfigure ./configure "${CONF_FLAGS[@]}")
emmake make -C $LIB_PATH clean
emmake make -C $LIB_PATH install -j$(nproc)