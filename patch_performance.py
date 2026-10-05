#!/usr/bin/env python3
from pathlib import Path
import sys

p = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("mesa/src/freedreno/vulkan/tu_device.cc")
text = p.read_text()

old_pipeline = "&device->pipeline_suballoc, device, 128 * 1024,"
new_pipeline = "&device->pipeline_suballoc, device, 512 * 1024,"
old_kgsl = "128 * 1024, TU_BO_ALLOC_INTERNAL_RESOURCE,\n                              \"kgsl_profiling_suballoc\""
new_kgsl = "512 * 1024, TU_BO_ALLOC_INTERNAL_RESOURCE,\n                              \"kgsl_profiling_suballoc\""

if old_pipeline not in text:
    raise SystemExit("pipeline_suballoc pattern not found; Mesa changed, review patch before building")
if old_kgsl not in text:
    raise SystemExit("kgsl_profiling_suballoc pattern not found; Mesa changed, review patch before building")

text = text.replace(old_pipeline, new_pipeline, 1)
text = text.replace(old_kgsl, new_kgsl, 1)
p.write_text(text)
print("Applied ThorA740 performance suballocator patch (128 KiB -> 512 KiB).")
