#!/usr/bin/env python3
"""Compare nono binaries with identical PATH, profile, command, and warmed caches."""

import argparse
import os
import statistics
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("baseline", type=Path)
parser.add_argument("patched", type=Path)
parser.add_argument("--profile", default="agents")
parser.add_argument("--runs", type=int, default=5)
args = parser.parse_args()
if args.runs < 1:
    parser.error("--runs must be positive")

binaries = {"baseline": args.baseline.resolve(), "patched": args.patched.resolve()}
env = os.environ.copy()
env["TOOL_SANDBOX_PROFILE_HOTPATH"] = "1"
samples = {name: [] for name in binaries}


def measure(binary):
    start = time.perf_counter()
    result = subprocess.run(
        [
            str(binary), "run", "-s", "--profile", args.profile, "--allow-cwd", "--",
            "bash", "--noprofile", "--norc", "-c", "printf 'READY\\n'",
        ],
        env=env, capture_output=True, text=True, timeout=60, check=True,
    )
    elapsed = time.perf_counter() - start
    if result.stdout.strip() != "READY":
        raise RuntimeError(f"unexpected stdout: {result.stdout!r}")
    detail = next(
        (line for line in result.stderr.splitlines() if "prepare:build_outer_exec_files:" in line),
        "outer-exec timing unavailable",
    )
    return elapsed, detail


# Warm both binaries, then alternate order to reduce page-cache/order bias.
for binary in binaries.values():
    measure(binary)
for index in range(args.runs):
    order = list(binaries) if index % 2 == 0 else list(reversed(binaries))
    for name in order:
        elapsed, detail = measure(binaries[name])
        samples[name].append(elapsed)
        print(f"{name}: {elapsed:.3f}s; {detail}", flush=True)

medians = {name: statistics.median(values) for name, values in samples.items()}
for name, median in medians.items():
    print(f"{name}: median {median:.3f}s")
print(f"reduction: {(1 - medians['patched'] / medians['baseline']) * 100:.1f}%")
