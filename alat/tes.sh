#!/bin/bash
# Tes whisper + VAD + telinga kedua + llama di Mac, dibanding jawaban Windows untuk rekaman publik jfk.wav / en.wav.
# Pakai: tes.sh <hasil whisper> <jfk.wav> <hasil resmi> [folder model]
WH="$1"; JFK="$2"; RS="$3"; M="${4:-$HOME/model}"; G=0; mkdir -p "$M"
ok() { echo "OK    $1"; }
no() { echo "GAGAL $1"; G=$((G+1)); }
jam() { python3 -c 'import time;print(time.time())'; }
lama() { python3 -c "import time;print('%.1f dtk'%(time.time()-$1))"; }
unduh() { [ -f "$2" ] || curl -fL --retry 3 -sS -o "$2" "$1"; echo "$3  $2" | shasum -a 256 -c - || no "unduhan $2"; }
bergantung() { # boleh: library sistem, @rpath, @loader_path, @executable_path
  local A X R
  A=$(lipo -archs "$1"); echo "$A" | grep -q arm64 || no "$(basename "$1") arsitektur $A"
  X=$(otool -L "$1" | tail -n +2 | awk '{print $1}' | grep -vE '^(/usr/lib/|/System/Library/|@rpath/|@loader_path/|@executable_path/)' || true)
  R=$(otool -l "$1" | awk '/LC_RPATH/{f=1} f&&/ path /{print $2; f=0}' | tr '\n' ' ')
  [ -z "$X" ] && ok "$(basename "$1") tanpa Homebrew; minos $(otool -l "$1" | awk '/minos/{print $2; exit}'); rpath: ${R:--}" || no "$(basename "$1") bergantung: $X"
}
for b in whisper-cli whisper-server whisper-vad-speech-segments; do bergantung "$WH/$b"; done
bergantung "$RS/ctc/bin/sherpa-onnx-offline"
for f in "$RS"/ctc/lib/*.dylib; do [ -L "$f" ] || bergantung "$f"; done
bergantung "$RS/llama-b12532/llama-server"
for f in "$RS"/llama-b12532/*.dylib; do [ -L "$f" ] || bergantung "$f"; done

unduh https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin "$M/silero.bin" 29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf
unduh https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin "$M/turbo.bin" 394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2
unduh https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12.tar.bz2 "$M/ctc.tar.bz2" cdcd0559c7c73efed54209a926e321afc914d046c5fdbf3665f00dc78180e5ed

V="$("$WH/whisper-vad-speech-segments" -vm "$M/silero.bin" -f "$JFK" -t 3 -vt 0.5 -np 2>&1 | sed -nE 's/.*start = ([0-9.]+), end = ([0-9.]+).*/\1-\2/p' | tr '\n' ' ')"
W="29.00-221.00 330.00-377.00 400.00-435.00 538.00-765.00 816.00-1059.00 "
echo "      VAD mac     : $V"; echo "      VAD windows : $W"
if python3 -c '
import sys
p=lambda s:[[float(x) for x in t.split("-")] for t in s.split()]
a,b=p(sys.argv[1]),p(sys.argv[2])
sys.exit(0 if len(a)==len(b) and all(abs(x-y)<=5 for s,t in zip(a,b) for x,y in zip(s,t)) else 1)' "$V" "$W"; then ok "VAD = Windows (beda <= 0,05 dtk)"; else no "VAD beda dari Windows"; fi

for mode in CPU Metal; do
  S=$(jam)
  if [ $mode = CPU ]; then O=$("$WH/whisper-cli" -m "$M/turbo.bin" -l en -t 3 -np -ng -f "$JFK" 2>err.txt </dev/null); C=$?
  else O=$(perl -e 'alarm 600; exec @ARGV' "$WH/whisper-cli" -m "$M/turbo.bin" -l en -t 3 -np -f "$JFK" 2>err.txt </dev/null); C=$?; fi
  echo "      whisper $mode: $(lama "$S") | $(echo "$O" | tr '\n' ' ')"
  if echo "$O" | grep -q "ask not what your country can do for you, ask what you can do for your country"; then ok "whisper $mode teks = Windows"
  elif [ $mode = Metal ]; then echo "INFO  whisper Metal tidak cocok/jalan di runner (kode $C): $(tail -2 err.txt | tr '\n' ' ')"
  else no "whisper CPU (kode $C)"; tail -5 err.txt; fi
done

mkdir -p "$M/ctc"; tar -xjf "$M/ctc.tar.bz2" -C "$M/ctc" --strip-components 1; shasum -a 256 "$M/ctc/model.int8.onnx"
S=$(jam)
O=$("$RS/ctc/bin/sherpa-onnx-offline" --print-args=false --tokens="$M/ctc/tokens.txt" --omnilingual-asr-model="$M/ctc/model.int8.onnx" --num-threads=3 "$M/ctc/test_wavs/en.wav" 2>&1)
echo "      telinga kedua: $(lama "$S") | $(echo "$O" | grep -oE '"timestamps": \[[^]]{0,70}' | head -1)"
if echo "$O" | grep -q '"text": "ask not what your country can do for you ask what you can do for your country"'; then ok "telinga kedua teks = Windows"; else no "telinga kedua"; echo "$O" | tail -5; fi

if (cd "$RS/llama-b12532" && ./llama-server --version 2>&1 | tail -2); then ok "llama-server menyala"; else no "llama-server"; fi
echo; [ $G = 0 ] && echo "SEMUA LULUS" || echo "$G GAGAL"
[ $G = 0 ]
