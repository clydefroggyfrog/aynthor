#!/usr/bin/env bash
set -euo pipefail

FLAVOR="${1:-both}"
case "$FLAVOR" in
  balanced|performance|both) ;;
  *) echo "usage: $0 [balanced|performance|both]" >&2; exit 2 ;;
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

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
for c in git curl unzip zip python3 meson ninja pkg-config; do need "$c"; done

if [[ ! -x "$TOOLBIN/aarch64-linux-android${ANDROID_API}-clang" ]]; then
  echo "Downloading Android NDK $NDK_REV..."
  curl -L --fail --retry 3 "https://dl.google.com/android/repository/android-ndk-${NDK_REV}-linux.zip" -o "$WORK/ndk.zip"
  rm -rf "$NDK_DIR"
  unzip -q "$WORK/ndk.zip" -d "$WORK"
fi

if [[ ! -d "$MESA_DIR/.git" ]]; then
  echo "Cloning upstream Mesa..."
  git clone --filter=blob:none https://gitlab.freedesktop.org/mesa/mesa.git "$MESA_DIR" || \
    git clone --filter=blob:none https://github.com/mirror/mesa.git "$MESA_DIR"
fi

git -C "$MESA_DIR" fetch --depth=1 origin "$MESA_REF"
git -C "$MESA_DIR" checkout --detach FETCH_HEAD
MESA_SHA="$(git -C "$MESA_DIR" rev-parse --short=10 HEAD)"
MESA_VERSION="$(tr -d '\n' < "$MESA_DIR/VERSION")"

write_cross() {
  local cross="$1"
  cat > "$cross" <<CROSS
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
c_args = ['-O3', '-mtune=cortex-x3', '-ffunction-sections', '-fdata-sections']
cpp_args = ['-O3', '-mtune=cortex-x3', '-ffunction-sections', '-fdata-sections']
c_link_args = ['-Wl,--gc-sections']
cpp_link_args = ['-Wl,--gc-sections']
CROSS
}

build_one() {
  local flavor="$1"
  local src="$WORK/mesa-$flavor"
  local bld="$WORK/build-$flavor"
  local prefix="$WORK/install-$flavor"
  local cross="$WORK/android-aarch64-$flavor.ini"

  rm -rf "$src" "$bld" "$prefix"
  git clone --shared "$MESA_DIR" "$src" >/dev/null
  git -C "$src" checkout --detach "$MESA_DIR/.git" >/dev/null 2>&1 || true
  # Ensure the worktree points at the exact checked-out Mesa commit.
  git -C "$src" reset --hard "$(git -C "$MESA_DIR" rev-parse HEAD)" >/dev/null

  if [[ "$flavor" == "performance" ]]; then
    python3 "$ROOT/scripts/patch_performance.py" "$src/src/freedreno/vulkan/tu_device.cc"
  fi

  write_cross "$cross"

  meson setup "$bld" "$src" \
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

  ninja -C "$bld" install

  local so
  so="$(find "$prefix" -type f -name 'libvulkan_freedreno.so' -print -quit)"
  [[ -n "$so" && -f "$so" ]] || { echo "Driver binary not found after build" >&2; exit 1; }

  local pretty="Balanced"
  [[ "$flavor" == "performance" ]] && pretty="Performance"
  local pkgdir="$WORK/pkg-$flavor"
  rm -rf "$pkgdir" && mkdir -p "$pkgdir"
  cp "$so" "$pkgdir/libvulkan_freedreno.so"
  "$TOOLBIN/llvm-strip" --strip-unneeded "$pkgdir/libvulkan_freedreno.so" || true

  cat > "$pkgdir/meta.json" <<META
{
  "schemaVersion": 1,
  "name": "ThorA740 $pretty ($MESA_SHA)",
  "description": "AYN Thor Snapdragon 8 Gen 2 / Adreno 740 Turnip build for Eden; Mesa $MESA_VERSION git $MESA_SHA",
  "author": "ThorA740 Driver Kit",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "$MESA_VERSION-$MESA_SHA",
  "minApi": 33,
  "libraryName": "libvulkan_freedreno.so"
}
META

  (cd "$pkgdir" && zip -9 -q "$OUT/ThorA740-${pretty}-${MESA_SHA}.zip" libvulkan_freedreno.so meta.json)
  sha256sum "$OUT/ThorA740-${pretty}-${MESA_SHA}.zip" > "$OUT/ThorA740-${pretty}-${MESA_SHA}.zip.sha256"
  echo "Built $OUT/ThorA740-${pretty}-${MESA_SHA}.zip"
}

if [[ "$FLAVOR" == "balanced" || "$FLAVOR" == "both" ]]; then build_one balanced; fi
if [[ "$FLAVOR" == "performance" || "$FLAVOR" == "both" ]]; then build_one performance; fi

printf '\nMesa source: %s (%s)\n' "$MESA_VERSION" "$MESA_SHA"
printf 'Outputs:\n'
ls -lh "$OUT"/*.zip "$OUT"/*.sha256
