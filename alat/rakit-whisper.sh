#!/bin/bash
# whisper.cpp b5454 (commit sama dengan Windows) untuk macOS Apple Silicon: statis, Metal + Accelerate, tanpa OpenMP.
set -euo pipefail
W="${1:-$HOME/rakit-w}"; SHA=d1be6fde11ac6e0407606b4e42fe72d34add8037
mkdir -p "$W/src" "$W/hasil"; cd "$W/src"; git init -q
git fetch -q --depth 1 https://github.com/ggml-org/whisper.cpp.git $SHA; git checkout -q FETCH_HEAD
[ "$(git rev-parse HEAD)" = $SHA ]
export MACOSX_DEPLOYMENT_TARGET=13.3
cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3 -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF \
  -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_CCACHE=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_SDL2=OFF -DWHISPER_CURL=OFF
cmake --build b -j"$(sysctl -n hw.ncpu)" --target whisper-cli whisper-server whisper-vad-speech-segments
cp b/bin/whisper-cli b/bin/whisper-server b/bin/whisper-vad-speech-segments LICENSE "$W/hasil/"
for b in whisper-cli whisper-server whisper-vad-speech-segments; do strip -x "$W/hasil/$b"; codesign --force -s - "$W/hasil/$b"; done
cp samples/jfk.wav "$W/jfk.wav"; ls -la "$W/hasil"
