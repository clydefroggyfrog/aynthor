# Eden profile for AYN Thor / Adreno 740

Start with Eden defaults and change only one variable at a time.

## Baseline (recommended)

- GPU driver: ThorA740 Balanced or Performance
- Pipeline workers: **4**
- Async GPU: **Off** initially
- Async Vulkan presentation: **Off** initially
- Fast GPU Time: test **On** for games that benefit; revert if timing breaks
- Resolution: start at **1x handheld** for performance testing
- VSync: game-dependent; do not compare two drivers with different VSync modes

## Turnip environment variables

Eden supports Turnip environment variables. For the first benchmark, leave `TU_DEBUG` empty.

Suggested optional tests:

### Adaptive autotune test

```text
TU_AUTOTUNE_ALGO=profiled
MESA_SHADER_CACHE_MAX_SIZE=4G
```

Mesa documents `profiled` as more accurate than the default bandwidth estimator, but it can produce more FPS variance while learning. Test it only after getting a clean baseline.

### Compatibility fallback

```text
TU_AUTOTUNE_ALGO=bandwidth
```

This is Mesa's default autotune algorithm and is the safest comparison point.

### Only for known game/device issues

```text
TU_DEBUG=gmem
```

or

```text
TU_DEBUG=noubwc
```

Do **not** enable these globally. They are debugging/compatibility controls and can reduce performance in games that do not need them.
