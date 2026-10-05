#!/usr/bin/env python3

from pathlib import Path
import sys


if len(sys.argv) > 1:
    path = Path(sys.argv[1])
else:
    path = Path(
        "mesa/src/freedreno/vulkan/tu_device.cc"
    )


if not path.exists():
    raise SystemExit(
        f"Turnip source file does not exist: {path}"
    )


text = path.read_text()


pipeline_old = (
    "&device->pipeline_suballoc, device, "
    "128 * 1024,"
)

pipeline_new = (
    "&device->pipeline_suballoc, device, "
    "512 * 1024,"
)


kgsl_old = (
    "128 * 1024, "
    "TU_BO_ALLOC_INTERNAL_RESOURCE,"
)

kgsl_new = (
    "512 * 1024, "
    "TU_BO_ALLOC_INTERNAL_RESOURCE,"
)


changes = 0


if pipeline_old in text:

    text = text.replace(
        pipeline_old,
        pipeline_new,
        1
    )

    changes += 1

    print(
        "Changed pipeline allocator "
        "128 KiB -> 512 KiB"
    )

else:

    print(
        "Pipeline allocator pattern "
        "was not found."
    )


if kgsl_old in text:

    text = text.replace(
        kgsl_old,
        kgsl_new,
        1
    )

    changes += 1

    print(
        "Changed KGSL allocator "
        "128 KiB -> 512 KiB"
    )

else:

    print(
        "KGSL allocator pattern "
        "was not found."
    )


if changes == 0:

    raise SystemExit(
        "Performance patch could not be applied. "
        "Mesa source layout may have changed."
    )


path.write_text(text)


print(
    "Thor A740 performance patch applied."
)
