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
  --enable-libvpx

  # Component pruning. The app drives a FIXED set of encoders, muxers and
  # filters (src/ffmpeg/job/args.ts is the only place that builds an ffmpeg
  # command line), so everything else is dead weight that LTO cannot drop:
  # allcodecs.c/allfilters.c reference every *enabled* component, which
  # makes them all reachable from the linker's point of view.
  #
  # DECODERS, DEMUXERS, PARSERS and BSFs stay fully enabled on purpose --
  # uploads are arbitrary, so breadth on the decode side is worth its bytes.
  --disable-encoders
  --enable-encoder=aac,png,libwebp,libx264,libx265,libaom_av1,libsvtav1,libvpx_vp9,opus
  --disable-muxers
  # matroska rides along with webm: matroskaenc.c compiles its
  # BlockAdditionMapping writer only under CONFIG_MATROSKA_MUXER, and
  # without it a webm with vp9 alpha gets its MaxBlockAdditionID patched
  # over the start of the video TrackEntry (a corrupt file)
  --enable-muxer=mp4,mov,image2,webm,matroska
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
  #
  # Transparent export and masks: lutrgb (a mask clip's picture made grey
  # or white, and inverted), shuffleplanes (copies that grey into the
  # alpha plane) and blend (multiplies the composite's alpha by it). The
  # alpha itself leaves as vp9 yuva420p in webm, with ffmpeg's native opus
  # encoder for the sound (webm cannot carry aac).
  --enable-filter=scale,zscale,crop,select,aselect,setpts,asetpts,setparams,fps,format,aformat,tonemap,aresample,anull,null,trim,atrim,color,setsar,overlay,colorchannelmixer,adelay,afade,volume,amix,apad,fade,chromakey,despill,transpose,hflip,vflip,rotate,lutrgb,shuffleplanes,blend
  # aom is built encoder-only now (dav1d decodes av1 and ffmpeg prefers
  # it), so the libaom decoder wrapper has no library behind it
  --disable-decoder=libaom_av1
  # libvpx is built encoder-only too; the native vp8/vp9 decoders stay
  --disable-decoder=libvpx_vp8,libvpx_vp9
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
