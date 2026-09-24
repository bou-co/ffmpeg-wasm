#!/bin/bash

set -eo pipefail

SCRIPT_ROOT=$(dirname $0)

source $SCRIPT_ROOT/init-emscripten.sh

if [ "$FFMPEG_SKIP_LIBS" = false ] ; then
    $SCRIPT_ROOT/build-zlib.sh
    $SCRIPT_ROOT/build-aom.sh
    $SCRIPT_ROOT/build-dav1d.sh
    $SCRIPT_ROOT/build-libwebp.sh
    $SCRIPT_ROOT/build-svtav1.sh
    $SCRIPT_ROOT/build-zimg.sh

    # GPL
    $SCRIPT_ROOT/build-x264.sh
    $SCRIPT_ROOT/build-x265.sh
fi

$SCRIPT_ROOT/configure-ffmpeg.sh
$SCRIPT_ROOT/build-ffmpeg.sh
$SCRIPT_ROOT/customize-ffmpeg.sh