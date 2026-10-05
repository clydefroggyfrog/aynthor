#!/usr/bin/env bash
set -euo pipefail

FLAVOR="${1:-both}"

case "$FLAVOR" in
  balanced|performance|both)
    ;;
  *)
    echo "usage: $0 [balanced|performance|both]" >&2
    exit 2
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$ROOT/.work}"
OUT="${OUT:-$ROOT/out}"

MESA_REF="${MESA_REF:-main}"
NDK_REV="${NDK_REV:-r29}"
ANDROID_API="${ANDROID_API:-33}"

NDK_DIR="$WORK/android-ndk-$NDK_REV"
MESA_DIR="$WORK/mesa"
TOOLBIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"

mkdir -p "$WORK" "$OUT"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

for c in git curl unzip zip python3 meson ninja pkg-config; do
  need "$c"
done

if [[ ! -x "$TOOLBIN/aarch64-linux-android${ANDROID_API}-clang" ]]; then
  echo "Downloading Android NDK $NDK_REV..."

  curl -L \
    --fail \
    --retry 3 \
    "https://dl.google.com/android/repository/android-ndk-${NDK_REV}-linux.zip" \
    -o "$WORK/ndk.zip"

  rm -rf "$NDK_DIR"
  unzip -q "$WORK/ndk.zip" -d "$WORK"
fi

if [[ ! -d "$MESA_DIR/.git" ]]; then
  echo "Cloning Mesa..."

  git clone \
    --filter=blob:none \
    https://gitlab.freedesktop.org/mesa/mesa.git \
    "$MESA_DIR" || \
  git clone \
    --filter=blob:none \
    https://github.com/mirror/mesa.git \
    "$MESA_DIR"
fi

echo "Fetching Mesa ref: $MESA_REF"

git -C "$MESA_DIR" fetch --depth=1 origin "$MESA_REF"
git -C "$MESA_DIR" checkout --detach FETCH_HEAD

MESA_SHA="$(git -C "$MESA_DIR" rev-parse --short=10 HEAD)"
MESA_VERSION="$(tr -d '\n' < "$MESA_DIR/VERSION")"

echo "Mesa version: $MESA_VERSION"
echo "Mesa commit: $MESA_SHA"

write_cross() {
  local cross="$1"

  cat > "$cross" <<EOF
[binaries]
c = '$TOOLBIN/aarch64-linux-android${ANDROID_API}-clang'
cpp = '$TOOLBIN/aarch64-linux-android${ANDROID_API}-clang++'
ar = '$TOOLBIN/llvm-ar'
strip = '$TOOLBIN/llvm-strip'
ranlib = '$TOOLBIN/llvm-ranlib'
ld = '$TOOLBIN/ld.lld'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=/nonexistent', 'pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'

[built-in options]
c_args = [
  '-O3',
  '-mtune=cortex-x3',
  '-ffunction-sections',
  '-fdata-sections'
]

cpp_args = [
  '-O3',
  '-mtune=cortex-x3',
  '-ffunction-sections',
  '-fdata-sections'
]

c_link_args = [
  '-Wl,--gc-sections'
]

cpp_link_args = [
  '-Wl,--gc-sections'
]
EOF
}

build_one() {

  local flavor="$1"

  local src="$WORK/mesa-$flavor"
  local bld="$WORK/build-$flavor"
  local prefix="$WORK/install-$flavor"
  local cross="$WORK/android-aarch64-$flavor.ini"

  echo
  echo "======================================"
  echo "Building Thor A740 $flavor driver"
  echo "======================================"

  rm -rf "$src" "$bld" "$prefix"

  git clone "$MESA_DIR" "$src"

  git -C "$src" checkout --detach "$(
    git -C "$MESA_DIR" rev-parse HEAD
  )"

  if [[ "$flavor" == "performance" ]]; then

    echo "Applying Thor A740 performance patch..."

    python3 \
      "$ROOT/scripts/patch_performance.py" \
      "$src/src/freedreno/vulkan/tu_device.cc"

  fi

  write_cross "$cross"

  meson setup \
    "$bld" \
    "$src" \
    --cross-file "$cross" \
    --prefix "$prefix" \
    -Dbuildtype=release \
    -Dstrip=true \
    -Dplatforms=android \
    -Dplatform-sdk-version="$ANDROID_API" \
    -Dandroid-stub=true \
    -Dandroid-libbacktrace=disabled \
    -Dgallium-drivers= \
    -Dvulkan-drivers=freedreno \
    -Dvulkan-beta=true \
    -Dfreedreno-kmds=kgsl \
    -Degl=disabled \
    -Dvideo-codecs= \
    -Dshader-cache=enabled \
    -Dshader-cache-default=true \
    -Dshader-cache-max-size=4G

  ninja -C "$bld"

  DESTDIR="$prefix" ninja -C "$bld" install

  echo "Searching for libvulkan_freedreno.so..."

  so="$(find "$prefix" "$bld" \
    -type f \
    -name 'libvulkan_freedreno.so' \
    -print \
    -quit)"

  if [[ -z "$so" || ! -f "$so" ]]; then
    echo "ERROR: libvulkan_freedreno.so was not generated."
    exit 1
  fi

  local pretty="Balanced"

  if [[ "$flavor" == "performance" ]]; then
    pretty="Performance"
  fi

  local pkgdir="$WORK/pkg-$flavor"

  rm -rf "$pkgdir"
  mkdir -p "$pkgdir"

  cp "$so" "$pkgdir/libvulkan_freedreno.so"

  "$TOOLBIN/llvm-strip" \
    --strip-unneeded \
    "$pkgdir/libvulkan_freedreno.so" || true

  cat > "$pkgdir/meta.json" <<EOF
{
  "schemaVersion": 1,
  "name": "ThorA740 $pretty ($MESA_SHA)",
  "description": "AYN Thor Snapdragon 8 Gen 2 / Adreno 740 Turnip driver for Eden",
  "author": "ThorA740 Driver Kit",
  "packageVersion": "1",
  "vendor": "Mesa Turnip",
  "driverVersion": "$MESA_VERSION-$MESA_SHA",
  "minApi": 33,
  "libraryName": "libvulkan_freedreno.so"
}
EOF

  DRIVER_ZIP="$OUT/ThorA740-${pretty}-${MESA_SHA}.zip"

  (
    cd "$pkgdir"

    zip -9 \
      -q \
      "$DRIVER_ZIP" \
      libvulkan_freedreno.so \
      meta.json
  )

  sha256sum "$DRIVER_ZIP" \
    > "$DRIVER_ZIP.sha256"

  echo
  echo "Created:"
  echo "$DRIVER_ZIP"
}

if [[ "$FLAVOR" == "balanced" || "$FLAVOR" == "both" ]]; then
  build_one balanced
fi

if [[ "$FLAVOR" == "performance" || "$FLAVOR" == "both" ]]; then
  build_one performance
fi

echo
echo "======================================"
echo "Thor A740 driver build complete"
echo "======================================"

echo
echo "Mesa:"
echo "$MESA_VERSION ($MESA_SHA)"

echo
echo "Output files:"
ls -lh "$OUT"
