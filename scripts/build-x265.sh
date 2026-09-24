#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/x265

# 8-BIT ONLY. x265 used to be built here as a multilib -- main + main10 + main12
# compiled separately and emar-merged into one archive -- but this app always
# hands the encoder 8-bit yuv420p (`-pix_fmt yuv420p` on every invocation), and
# HDR sources are tonemapped down to 8-bit bt709 by the zscale/tonemap chain
# long before they reach x265. The 10- and 12-bit halves were therefore
# unreachable code worth roughly two thirds of libx265.a, which is what makes
# them worth cutting against Cloudflare's 25 MiB per-asset limit.
#
# To restore the multilib: re-add the 10bit/12bit configure passes with
# -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF (plus -DMAIN12=ON for the 12-bit one),
# point the main pass at them via -DEXTRA_LIB/-DLINKED_10BIT/-DLINKED_12BIT,
# and emar-merge the three archives before `make install`.
#
# NOTE: x265 declares cmake_minimum_required(VERSION 2.8.8), which CMake 4
# rejects outright -- this needs cmake 3.x (the repo-local .toolvenv supplies
# one; see var.sh).

FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE
  -DCMAKE_C_FLAGS="$CFLAGS"
  -DCMAKE_CXX_FLAGS="$CXXFLAGS"
  -DX64=1
  -DX86_64=1
  -DENABLE_LIBNUMA=OFF
  -DENABLE_SHARED=OFF
  -DENABLE_CLI=OFF
  -DCMAKE_INSTALL_PREFIX=$BUILD_DIR
)

cd $LIB_PATH/source
rm -rf build
mkdir -p build/main
cd build/main
emmake cmake ../.. -G"Unix Makefiles" "${FLAGS[@]}"
emmake make clean
emmake make -j$(nproc)
emmake make install -j$(nproc)

cd $ROOT_DIR
