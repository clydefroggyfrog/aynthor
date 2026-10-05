# Eden Thor A740 Turnip Driver Kit

A reproducible Mesa Turnip build kit tuned for **AYN Thor / Thor Pro / Thor Max** hardware using **Snapdragon 8 Gen 2 / Adreno 740** and intended primarily for the **Eden Android emulator**.

This project builds two AdrenoTools-compatible driver packages:

- **ThorA740 Balanced** — current upstream Mesa Turnip, Android/KGSL-only build, 4 GB shader-cache ceiling, Cortex-X3 scheduling tune.
- **ThorA740 Performance** — everything in Balanced plus 512 KiB Turnip pipeline and KGSL profiling suballocator blocks (up from upstream 128 KiB). This is experimental and must be benchmarked game-by-game.

## Why this approach

The goal is sustained performance and frame-time consistency, not a fake version-number bump. The build deliberately does **not** force max GPU clocks, globally force GMEM/SYSMEM, disable UBWC, or enable Mesa LTO. Those choices can increase heat, break games, or reduce compatibility.

## Target

- Device: AYN Thor family
- SoC: Snapdragon 8 Gen 2 / QCS8550
- GPU: Adreno 740
- Android: 13+ (API 33+)
- Emulator package format: AdrenoTools `.zip` / Eden custom GPU driver
- Mesa source: upstream `main` by default, exact git SHA embedded in package metadata

## Build with GitHub Actions

1. Create a GitHub repository and upload this folder.
2. Open **Actions → Build Eden Thor A740 driver → Run workflow**.
3. Leave `mesa_ref` as `main` for the latest upstream Turnip, or enter a Mesa git SHA/tag to pin it.
4. Download the `ThorA740-drivers` artifact after the workflow completes.
5. You will get two packages:
   - `ThorA740-Balanced-<sha>.zip`
   - `ThorA740-Performance-<sha>.zip`

## Build on Ubuntu locally

```bash
sudo apt-get update
sudo apt-get install -y git curl unzip zip ninja-build pkg-config flex bison python3 python3-pip patchelf clang lld ccache
python3 -m pip install --user -U meson mako pyyaml packaging
./scripts/build.sh both
```

The script downloads Android NDK r29 and upstream Mesa if they are not present. Set `MESA_REF=<sha-or-tag>` to pin the source.

## Install in Eden

Install the produced ZIP through Eden's custom GPU driver manager, select it for the game, fully close Eden, then relaunch the game.

Recommended first-pass Eden settings for the AYN Thor are in [`config/EDEN_PROFILE.md`](config/EDEN_PROFILE.md).

## Benchmark against MrPurple T30

Do not assume this driver is faster just because it is newer or device-specific. Use the same game scene, resolution, Eden settings, fan/power mode, and shader-cache state. See [`config/BENCHMARK.md`](config/BENCHMARK.md).

A good result is not only higher average FPS: look for fewer shader stalls, better 1% lows / frame-time consistency, fewer graphics regressions, and less thermal throttling after 10–15 minutes.

## Important

This kit creates a custom open-source Turnip build. It does not modify Android system partitions, does not require root for Eden, and does not contain Nintendo keys, firmware, games, or proprietary Qualcomm driver binaries.

Mesa is a separate upstream project under its own licenses. This repository only contains build/packaging scripts and small optional source transformations.
