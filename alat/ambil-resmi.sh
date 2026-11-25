#!/bin/bash
# Program resmi siap pakai (dicek SHA-256): sherpa-onnx v2.0.3 (telinga kedua) dan llama.cpp b12532, macOS arm64.
set -euo pipefail
W="${1:-$HOME/rakit-r}"; mkdir -p "$W/unduh" "$W/hasil"; cd "$W/unduh"
unduh() { curl -fL --retry 3 -sS -o "$2" "$1"; echo "$3  $2" | shasum -a 256 -c -; }
unduh https://github.com/k2-fsa/sherpa-onnx/releases/download/v2.0.3/sherpa-onnx-v2.0.3-osx-arm64-shared-no-tts.tar.bz2 sherpa.tar.bz2 611aee84500fbc8a1295c05c15afeefa74380602ddc1a212e8a703cfe76981fd
unduh https://github.com/ggml-org/llama.cpp/releases/download/b12532/llama-b12532-bin-macos-arm64.tar.gz llama.tar.gz e3162c7d47e796435bcdef4ca348c56f4a315eebefc90109ca15d40e1d136ca8
mkdir -p s l; tar -xjf sherpa.tar.bz2 -C s --strip-components 1; tar -xzf llama.tar.gz -C l
ls -la s/bin/sherpa-onnx-offline s/lib l
mkdir -p "$W/hasil/ctc/bin" "$W/hasil/ctc/lib"
cp s/bin/sherpa-onnx-offline "$W/hasil/ctc/bin/"
cp -a s/lib/*.dylib "$W/hasil/ctc/lib/"
cp -a l/llama-b12532 "$W/hasil/llama-b12532"
du -sh "$W/hasil"/*
