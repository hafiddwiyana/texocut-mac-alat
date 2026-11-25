#!/bin/bash
# Tes ffmpeg Mac. Pakai: tes.sh <folder hasil>. Keluar 1 kalau ada yang GAGAL. INFO = dilaporkan, tidak menggagalkan.
H="$(cd "$1" && pwd)"; HERE="$(cd "$(dirname "$0")" && pwd)"
FF="$H/ffmpeg"; FP="$H/ffprobe"; G=0
T="$(mktemp -d)/tes spasi é"; mkdir -p "$T"; cd "$T" || exit 1
ok() { echo "OK    $1"; }
no() { echo "GAGAL $1"; G=$((G+1)); }
cek() { local n="$1"; shift; if "$@" >log.txt 2>&1 </dev/null; then ok "$n"; else no "$n"; tail -5 log.txt | sed 's/^/        /'; fi; }
"$FF" -hide_banner -version | head -3
for b in ffmpeg ffprobe; do
  [ "$(lipo -archs "$H/$b")" = arm64 ] && ok "$b arm64" || no "$b bukan arm64"
  echo "      minos $(otool -l "$H/$b" | awk '/minos/{print $2; exit}'), $(du -m "$H/$b" | cut -f1) MB"
  L=$(otool -L "$H/$b" | tail -n +2 | awk '{print $1}')
  X=$(echo "$L" | grep -vE '^(/usr/lib/|/System/Library/)' || true)
  [ -z "$X" ] && ok "$b hanya memakai library bawaan macOS ($(echo "$L" | wc -l | tr -d ' ') buah)" || no "$b bergantung: $X"
  codesign --verify --strict "$H/$b" && ok "$b tanda tangan ad-hoc sah" || no "$b tanda tangan"
done
"$FF" -hide_banner -filters 2>/dev/null | awk '{print $2}' | sort -u > f.txt
K=""; N=0
while read -r f; do [ -z "$f" ] && continue; N=$((N+1)); grep -qx "$f" f.txt || K="$K $f"; done < "$HERE/filter-wajib.txt"
[ -z "$K" ] && ok "$N filter engine lengkap" || no "filter hilang:$K"
"$FF" -hide_banner -encoders 2>/dev/null | awk '{print $2}' > e.txt
"$FF" -hide_banner -decoders 2>/dev/null | awk '{print $2}' > d.txt
for e in libx264 h264_videotoolbox aac pcm_s16le pcm_f32le png rawvideo; do grep -qx $e e.txt && ok "encoder $e" || no "encoder $e"; done
for d in h264 hevc libdav1d vp9 mjpeg png webp aac mp3float opus flac pcm_s16le pcm_s24le prores; do grep -qx $d d.txt && ok "decoder $d" || no "decoder $d"; done

q=(-hide_banner -loglevel error -nostdin -y)
cek "encode x264+aac" "$FF" "${q[@]}" -f lavfi -i testsrc2=s=640x360:r=30:d=3 -f lavfi -i sine=f=440:d=3 -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart a.mp4
D=$("$FP" -v error -show_entries format=duration -of csv=p=0 a.mp4); echo "      durasi a.mp4 = $D"
awk "BEGIN{exit !($D>2.95 && $D<3.1)}" && ok "durasi 3 s" || no "durasi $D"
printf 'LUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n' > id.cube
cp "$HERE/uji-caption.ass" t.ass
v() { cek "filter $1" "$FF" "${q[@]}" -i a.mp4 -vf "$2" -an -f null -; }
a() { cek "filter $1" "$FF" "${q[@]}" -i a.mp4 -vn -af "$2" -f null -; }
v lut3d lut3d=id.cube
v bilateral bilateral=sigmaS=3:sigmaR=0.1
v perspective perspective=x0=10:y0=10
v eq eq=contrast=1.1:saturation=1.2
v cas cas=0.5
v gblur gblur=2
v unsharp unsharp
v exposure exposure=0.2
v geq "geq=lum='lum(X,Y)':cb='cb(X,Y)':cr='cr(X,Y)'"
v zoompan "zoompan=z='1.2':d=1:s=360x640"
v putar-potong "transpose=2,crop=202:360,scale=1080:1920,setsar=1"
a afftdn afftdn=nf=-25
a loudnorm loudnorm=I=-16
a deesser deesser
a agate agate
a ebur128 ebur128
cek "vidstab deteksi" "$FF" "${q[@]}" -i a.mp4 -vf vidstabdetect=result=trf.txt -f null -
cek "vidstab terapkan" "$FF" "${q[@]}" -i a.mp4 -vf vidstabtransform=input=trf.txt -an -c:v libx264 s.mp4
curl -fsSL -o lq.rnnn https://raw.githubusercontent.com/GregorR/rnnoise-models/master/leavened-quisling-2018-08-31/lq.rnnn
a arnndn arnndn=m=lq.rnnn
cek "caption (ass)" "$FF" "${q[@]}" -f lavfi -i color=black:s=640x360:d=1:r=30 -vf ass=t.ass -frames:v 1 cap.png
Y=$("$FF" -hide_banner -nostdin -loglevel error -i cap.png -vf "signalstats,metadata=print:file=-" -f null - 2>/dev/null | awk -F= '/YMAX/{print $2; exit}')
awk "BEGIN{exit !(${Y:-0}>150)}" && ok "tulisan caption benar-benar tergambar (terang $Y)" || no "caption kosong (terang $Y)"
[ -n "$TES_FOTO" ] && cp cap.png "$TES_FOTO/caption.png"
if "$FF" "${q[@]}" -f lavfi -i testsrc2=s=1080x1920:r=30:d=2 -pix_fmt yuv420p -c:v h264_videotoolbox -b:v 9000k -maxrate 13500k -bufsize 18000k vt.mp4 >log.txt 2>&1; then
  echo "INFO  VideoToolbox encode JALAN di runner ini"; else echo "INFO  VideoToolbox encode tidak jalan di runner: $(tail -1 log.txt)"; fi
if "$FF" "${q[@]}" -hwaccel videotoolbox -i a.mp4 -an -f null - >log.txt 2>&1; then echo "INFO  decode videotoolbox jalan $(tail -1 log.txt)"; else echo "INFO  decode videotoolbox gagal: $(tail -1 log.txt)"; fi
S=$(python3 -c 'import time;print(time.time())')
"$FF" "${q[@]}" -f lavfi -i testsrc2=s=1080x1920:r=30:d=10 -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p sp.mp4
python3 -c "import time;print('INFO  x264 1080x1920 10 dtk selesai dalam %.1f dtk'%(time.time()-$S))"
S=$(python3 -c 'import time;print(time.time())')
"$FF" "${q[@]}" -i sp.mp4 -vf vidstabdetect=shakiness=5:result=t2.txt -f null -
python3 -c "import time;print('INFO  vidstabdetect 1080x1920 10 dtk selesai dalam %.1f dtk (tanpa OpenMP)'%(time.time()-$S))"
echo; [ $G = 0 ] && echo "SEMUA LULUS" || echo "$G GAGAL"
[ $G = 0 ]
