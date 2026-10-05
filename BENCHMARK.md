# T30 vs ThorA740 benchmark procedure

Use a repeatable in-game section that is GPU-heavy and lasts at least 3 minutes.

1. Reboot the AYN Thor before each driver group if possible.
2. Use the same Eden build, game update/DLC, resolution, VSync, docked/handheld mode, fan mode, and power mode.
3. Keep Eden's pipeline worker count identical (start with 4).
4. First run: allow shaders to compile and note stutter, but do not use it as the final FPS result.
5. Runs 2–4: record average FPS, minimum/1% low if available, visible stutter, rendering errors, and temperature after 10 minutes.
6. Test in this order:
   - MrPurple T30
   - ThorA740 Balanced
   - ThorA740 Performance
7. If a custom build loses or glitches, switch that game back to T30. Driver choice should be per-game.

Suggested table:

| Game / scene | Driver | Avg FPS | 1% low / min | 10-min temp | Shader stutter | Visual issues |
|---|---:|---:|---:|---:|---|---|
| | T30 | | | | | |
| | ThorA740 Balanced | | | | | |
| | ThorA740 Performance | | | | | |
