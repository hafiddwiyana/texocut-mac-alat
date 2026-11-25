#!/bin/bash
# Rakit ffmpeg + ffprobe statis untuk macOS Apple Silicon. Versi (commit) sama dengan build Windows; lihat bahan.txt.
set -euo pipefail
cd "$(dirname "$0")"
HERE="$PWD"; W="${1:-$HOME/rakit}"; P="$W/pasang"; S="$W/sumber"
mkdir -p "$P" "$S"
export MACOSX_DEPLOYMENT_TARGET=13.3
export PKG_CONFIG_LIBDIR="$P/lib/pkgconfig"   # hanya library rakitan sendiri; library Homebrew tidak terlihat
unset PKG_CONFIG_PATH CPATH LIBRARY_PATH || true
J=$(sysctl -n hw.ncpu)
ambil() { # nama -> $S/nama, persis di commit bahan.txt
  local url sha; read -r _ url sha < <(grep "^$1 " "$HERE/bahan.txt")
  mkdir -p "$S/$1"; cd "$S/$1"; git init -q
  for i in 1 2 3; do git fetch -q --depth 1 "$url" "$sha" && break; echo "ulang ambil $1"; sleep 10; done
  git checkout -q FETCH_HEAD
  [ "$(git rev-parse HEAD)" = "$sha" ] || { echo "commit $1 tidak cocok"; exit 1; }
  echo "== $1 $sha"
}
M() { meson setup b --prefix="$P" -Dlibdir=lib --buildtype=release --default-library=static --wrap-mode=nofallback "$@"; ninja -C b -j"$J"; ninja -C b install; }

ambil fribidi; M -Dbin=false -Ddocs=false -Dtests=false
ambil libunibreak; bash ./bootstrap; ./configure --prefix="$P" --disable-shared --enable-static --with-pic; make -j"$J"; make install
ambil freetype; M -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dpng=disabled -Dtests=disabled -Dzlib=none -Dhvf=disabled
ambil harfbuzz; M -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled -Dpng=disabled -Dzlib=disabled -Dicu=disabled \
  -Draster=disabled -Dvector=disabled -Dgpu=disabled -Dgpu_demo=disabled -Dsubset=disabled -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled -Dutilities=disabled
ambil libass; M -Dtest=disabled -Dcompare=disabled -Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled -Dfontconfig=disabled -Dcoretext=enabled -Dasm=enabled -Dlibunibreak=enabled
ambil x264; ./configure --prefix="$P" --disable-cli --enable-static --enable-pic --disable-lavf --disable-swscale; make -j"$J"; make install
ambil vidstab; cmake -B b -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$P" -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF -DUSE_OMP=OFF -DSSE2_FOUND=FALSE; cmake --build b -j"$J"; cmake --install b
ambil dav1d; M -Denable_tools=false -Denable_tests=false
ls "$P/lib" "$P/lib/pkgconfig"

ambil ffmpeg
./configure --prefix="$W/ffmpeg" --pkg-config-flags=--static --arch=arm64 --cc=clang \
  --extra-cflags="-I$P/include -mmacosx-version-min=13.3" --extra-ldflags="-L$P/lib -mmacosx-version-min=13.3" --extra-libs="-lc++" \
  --extra-version=texocut-mac --enable-gpl --enable-version3 --enable-static --disable-shared --disable-autodetect \
  --disable-debug --disable-doc --disable-ffplay --disable-network \
  --enable-videotoolbox --enable-zlib --enable-iconv \
  --enable-libx264 --enable-libass --enable-libfreetype --enable-libfribidi --enable-libharfbuzz --enable-libvidstab --enable-libdav1d \
  || { tail -60 ffbuild/config.log; exit 1; }
make -j"$J"; make install
mkdir -p "$W/hasil"; cp "$W/ffmpeg/bin/ffmpeg" "$W/ffmpeg/bin/ffprobe" "$W/hasil/"
cp COPYING.GPLv3 "$W/hasil/LICENSE.txt"; cp "$HERE/bahan.txt" "$W/hasil/daftar-library.txt"
codesign --force -s - "$W/hasil/ffmpeg" "$W/hasil/ffprobe"
mkdir -p "$W/sumber-bersih"; for n in $(awk '{print $1}' "$HERE/bahan.txt"); do git -C "$S/$n" archive --prefix="$n/" HEAD | tar -xf - -C "$W/sumber-bersih"; done
ls "$W/hasil" "$W/sumber-bersih"
tar -czf "$W/sumber-ffmpeg-mac.tar.gz" -C "$W" sumber-bersih
ls -la "$W/hasil" "$W/sumber-ffmpeg-mac.tar.gz"
