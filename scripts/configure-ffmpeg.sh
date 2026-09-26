#!/bin/bash

set -euo pipefail
source $(dirname $0)/var.sh

LIB_PATH=modules/ffmpeg

FLAGS=(
  --target-os=none        # use none to prevent any os specific configurations
  --arch=$WASM_ARCH
  --cpu=generic
  --enable-cross-compile
  --enable-version3
  --enable-zlib
  --enable-libaom
  --enable-libdav1d
  --enable-libwebp
  --enable-libsvtav1
  --enable-libzimg

  # Component pruning. The app drives a FIXED set of encoders, muxers and
  # filters (src/ffmpeg/job/args.ts is the only place that builds an ffmpeg
  # command line), so everything else is dead weight that LTO cannot drop:
  # allcodecs.c/allfilters.c reference every *enabled* component, which
  # makes them all reachable from the linker's point of view.
  #
  # DECODERS, DEMUXERS, PARSERS and BSFs stay fully enabled on purpose --
  # uploads are arbitrary, so breadth on the decode side is worth its bytes.
  --disable-encoders
  --enable-encoder=aac,png,libwebp,libx264,libx265,libaom_av1,libsvtav1
  --disable-muxers
  --enable-muxer=mp4,mov,image2
  --disable-filters
  # named by videoFilters()/audioTrimFilter(): setparams select setpts crop
  # scale zscale format tonemap fps aselect asetpts. The rest are inserted
  # by the graph negotiator itself (format/aformat/aresample conversions,
  # null/anull for empty graphs, trim/atrim for output-side -ss/-t).
  # buffer/abuffer sources and sinks are always compiled -- allfilters.c
  # deliberately hides them from configure's grep, so naming them here
  # would be rejected as an unknown option.
  #
  # Edit mode's sequence export (src/ffmpeg/job/composition-args.ts) adds
  # its own set: color (the background clock), setsar, overlay and
  # colorchannelmixer (layering and opacity), and on the audio side
  # adelay, afade, volume, amix and apad (placement, fades, levels, the
  # mix and padding it to the sequence length), plus fade for picture
  # fades (it ramps the alpha of an rgba clip, revealing what is below).
  #
  # transpose, hflip, vflip and rotate are autorotate's: fftools inserts
  # them itself for any source with a display matrix (portrait phone video,
  # EXIF-rotated JPEGs), and fails with AVERROR_BUG when they are missing.
  # configure normally selects them for the ffmpeg program, but this build
  # uses --disable-programs and compiles fftools by hand, so they must be
  # named here.
  --enable-filter=scale,zscale,crop,select,aselect,setpts,asetpts,setparams,fps,format,aformat,tonemap,aresample,anull,null,trim,atrim,color,setsar,overlay,colorchannelmixer,adelay,afade,volume,amix,apad,fade,chromakey,despill,transpose,hflip,vflip,rotate
  # aom is built encoder-only now (dav1d decodes av1 and ffmpeg prefers
  # it), so the libaom decoder wrapper has no library behind it
  --disable-decoder=libaom_av1
  # no protocol other than file/pipe can work in wasm anyway
  --disable-network
  --disable-stripping
  --disable-programs      # disable programs build (incl. ffplay, ffprobe & ffmpeg)
  --disable-doc
  --disable-debug
  --disable-runtime-cpudetect
  --disable-autodetect    # disable external libraries auto detect
  --extra-cflags="$CFLAGS"
  --extra-cxxflags="$CXXFLAGS"
  --extra-ldflags="$LDFLAGS"
  --pkg-config-flags="--static --define-prefix"
  --nm=emnm
  --ar=emar
  --ranlib=emranlib
  --cc=emcc
  --cxx=em++
  --objcc=emcc
  --dep-cc=emcc
)

if [ "$FFMPEG_LGPL" = false ] ; then
    FLAGS+=(
        --enable-gpl
        --enable-libx264
        --enable-libx265
    )
fi

echo "FFMPEG_CONFIG_FLAGS=${FLAGS[@]}"
(cd $LIB_PATH && \
    PKG_CONFIG_PATH=$EM_PKG_CONFIG_PATH && \
    emconfigure ./configure "${FLAGS[@]}")
