# Experimental ELF metadata-region reads (Linux)

This patch avoids whole-file reads in nono 0.80.0 while retaining upstream's
`parse_elf32`, `parse_elf64`, `parse_dynamic`, numeric decoders and C-string
parsing:

- Read up to the initial 64 bytes, retaining upstream's short/non-ELF handling.
- Read each program header into a 32- or 56-byte stack buffer.
- Read the `PT_INTERP` path and `PT_DYNAMIC` region into owned buffers.
- Read the dynamic string table as one region. Reuse `read_cstr_string` for
  dependency names and RPATH/RUNPATH.

The parsing logic stays in `platform/linux.rs`. `elf-reader.rs` is only an I/O
helper using `FileExt::read_exact_at`, with checked offsets, file-bound checks,
and fallible allocation. It adds no unsafe code, persistent cache, or Cargo
dependency. ELF32/ELF64 little-endian support, library path resolution,
and command policies are retained.

## Bounds and trade-offs

Metadata regions are copied in full. No bytes are read merely to advance to a
later file offset. Each region is limited to **64 MiB**;
a larger region returns an error, never a fallback to whole-file reading. This
can reject unusual valid ELF files with exceptionally large metadata.

If `DT_STRSZ` is absent, only the remainder of the string table's file-backed
`PT_LOAD` region is considered, subject to the same limit; this fallback may
include unrelated bytes within that segment. Strings and metadata
ranges are validated more strictly than in some upstream malformed-file cases.

Concurrent updates are not an atomic snapshot. If truncation leaves fewer bytes
than a requested read requires, that read returns an I/O error.

## Enable

This experiment is **enabled by default on Linux** and disabled on other
platforms. To use upstream instead, set this in your Home Manager configuration:

```nix
dotfiles.nono.experimentalElfReader = false;
```

Apply Home Manager normally.
Home Manager supports this option only on Linux; explicitly enabling it on other
platforms fails an assertion. The patch does not change the profile JSON.
Benchmarks do not activate Home Manager.

## Build and compare without activation

The first build compiles nono with release optimization/LTO and can take tens
of minutes. Parser tests compile independently with `rustc`, avoiding a second
full build of nono's unit-test executable. The same derivation is cached after
its first successful build, while its output remains in the Nix store.

Run the following on Linux from the repository root (new files must be included
when using a Git flake). The benchmark requires the `agents` profile and `bash`
on PATH; replace `/path/to/unpatched/nono` with an unpatched binary:

```sh
nix build --impure --out-link /tmp/nono-region-reader --expr '
  let
    f = builtins.getFlake (toString ./.);
    pkgs = import f.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ f.inputs.llm-agents.overlays.shared-nixpkgs ];
    };
  in import ./home-manager/nono/reader-package.nix {
    nono = pkgs.llm-agents.nono;
    inherit (pkgs) python3 stdenv;
  }
'

python3 home-manager/nono/benchmark-startup.py \
  /path/to/unpatched/nono /tmp/nono-region-reader/bin/nono
```

The benchmark warms both binaries, alternates order and uses identical
PATH/profile/cwd/commands. It prints per-run outer-exec timings when available
and median total times (five measured runs per binary by default).
Arguments must point to distinct implementations; the installed `nono` may
already include the patch.

## Benchmark results

A saved Linux benchmark run compared unpatched nono 0.80.0 with the
metadata-region reader using the same PATH, `agents` profile, working directory,
and command. Both binaries were warmed once before seven measured runs per
binary, with the execution order alternating between runs.

| Metric | Unpatched | Metadata-region reader |
| --- | ---: | ---: |
| Median total elapsed time | 3.158 s | 0.538 s |
| Median outer-exec preparation | 2.780 s | 0.313 s |
| Execute allowlist paths | 2,240 | 2,240 |

Median total elapsed time decreased by **83.0%**. Total elapsed time includes
launching nono and running the benchmark command; outer-exec preparation is the
`prepare:build_outer_exec_files` diagnostic timing. Matching path counts alone
do not prove that allowlist contents are identical.

These are measurements from one environment with warmed caches, not a
performance guarantee. Results depend on the binaries on PATH, profile,
storage, and system load. The benchmark defaults to five measured runs; use
`--runs 7` to match the sample count above. Local paths and raw diagnostic logs
are omitted.

## Tests

`test-elf-reader.py` applies the production patch to an unmodified upstream
`platform/linux.rs`. It extracts the actual patched parsing functions and
compiles them with their actual I/O helper and tests, alongside the original
parser. No separately maintained parser is used as the implementation under test.

The 15 regression tests cover both ELF classes, interpreter paths, dependencies,
RPATH/RUNPATH and `$ORIGIN`, empty/non-ELF/static files, malformed offsets and
strings, truncation, and the allocation cap. An actual sparse 1 TiB file verifies
that unused file contents are not read. Oversized dynamic/string-table regions
are rejected without reading or allocating them. A sixteenth test compares the
original and patched results on real files.

The Nix build runs the 15 regression tests on generated fixtures. The sixteenth
test parses the built binary, the upstream binary, and the generated test
executable with both parsers and compares their metadata. It does not execute
those nono binaries or run the full upstream integration suite.

Standalone tests without rebuilding nono (requires Python 3, `patch`, and a
working `rustc` supporting Rust edition 2024). Use the unpatched source for nono
0.80.0; corpus paths must exist, so adjust them for your system:

```sh
python3 home-manager/nono/test-elf-reader.py \
  --source /path/to/unpatched/nono/crates/nono-cli/src/tool-sandbox/platform/linux.rs \
  --rustc /path/to/rustc \
  --corpus "$HOME/.nix-profile/bin" --corpus /usr/bin \
  --corpus /usr/sbin --corpus /usr/lib/x86_64-linux-gnu
```
