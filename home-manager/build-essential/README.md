# build-essential

A Home Manager module (`home-manager/build-essential`) that gives the
Nix-managed GCC a **stable runtime prefix**, so that generated ELF files reference

```
~/.local/nix-runtime/lib/ld-linux-x86-64.so.2
```

instead of a hash-pinned path such as

```
/nix/store/<hash>-glibc-*/lib/ld-linux-x86-64.so.2
```

The prefix is a symlink tree whose leaves point at the current glibc / GCC
runtime. Updating Home Manager moves the symlink; previously built binaries keep
running without a rebuild.

## Enable

The directory splits into `gcc.nix` (the runtime prefix below) and
`make.nix` (installs `pkgs.gnumake`). `default.nix` imports both. `autoconf` and
`pkg-config` live in their own `home-manager/autoconf` and
`home-manager/pkg-config` modules.

Always enabled on Linux. Non-Linux platforms use the stock `pkgs.gcc`.

```nix
{
  # optional:
  # dotfiles.buildEssential.libraries = [ pkgs.zlib pkgs.openssl ];
}
```

This module replaces `pkgs.gcc` in `home.packages` (both provide
`bin/gcc`), so `home-manager switch` installs these wrappers instead.

## Layout

```
~/.local/nix-runtime -> /nix/store/<hash>-nix-runtime-<gcc-version>
├── lib/       glibc: ld-linux, libc, crt*.o, libc.so script, extra libraries
├── lib64/     glibc multiarch loader objects, when present
├── gcc-lib/   libgcc_s, libstdc++, sanitizers, ...
└── include/   glibc headers (+ extra libraries' headers)
```

`gcc`, `cc`, `g++`, `c++` are wrappers around `pkgs.gcc-unwrapped` that pass
`-B`, `-isystem`, `-L`, `-Wl,-rpath` and `-Wl,--dynamic-linker` pointing at the
prefix. A `-B${pkgs.binutils-unwrapped}/bin/` entry pins the raw `as`/`ld`
regardless of `PATH` order (the wrapped `pkgs.binutils` `ld` would inject store
paths into RUNPATH). `cpp`, `gcc-ar`, `gcc-nm`, `gcc-ranlib`, `gcov`,
`gcov-dump`, `gcov-tool`, `lto-dump` are re-exposed verbatim.
`pkgs.binutils-unwrapped` is installed so `as` / `ld` resolve to raw Nix binutils
on `PATH`. The module also grants nono the unwrapped driver's `libexec` helper
dir (`cc1`, `collect2`) and `$RUNTIME/lib` (loader) via
`dotfiles.nono.commandPolicies.executableDirs`.

## Verification

```sh
gcc hello.c -o hello
./hello

readelf -l ./hello | grep interpreter   # -> ~/.local/nix-runtime/lib/ld-linux...
readelf -d ./hello | grep -E 'RPATH|RUNPATH|NEEDED'
strings ./hello | grep /nix/store       # expected: no output
```

Resolve dependencies with the intended loader, not the host `ldd`:

```sh
"$HOME/.local/nix-runtime/lib/ld-linux-x86-64.so.2" --list ./hello
```

GC / update test: build `hello`, update the Home Manager generation, then run
`hello` again without rebuilding. Because the prefix is a single `home.file`
symlink to a store derivation, it is both atomically swapped and kept as a GC
root.

## Caveats

- The ELF-visible paths are stable, but the runtime tree's leaves are **symlinks
  into the Nix store**. GC safety therefore relies on the Home Manager
  generation referencing the tree (which `home.file` guarantees). The store
  closure is not copied.
- The build side still needs the store: `pkgs.gcc-unwrapped` and its `libexec`
  helpers (`cc1`, `collect2`). The module grants those plus `$RUNTIME/lib`
  (loader) via `dotfiles.nono.commandPolicies.executableDirs`, and the prefix
  via `dotfiles.nono.filesystem.read`.
- The prefix must stay **non-writable** by the sandbox. It is a read grant, not
  `filesystem.allow`; otherwise nono refuses to start and an agent could swap the
  loader.
- Linux / ELF only; on `x86_64` and `aarch64` the loader name is taken from
  `pkgs.stdenv.cc.bintools.dynamicLinker`.
- Extra `libraries` with colliding file names fail the build rather than
  silently shadowing an earlier library. Their **transitive** dependencies are
  not covered by the binary's (non-transitive) RUNPATH: they resolve through
  the library's own RUNPATH or the loader's default search path, which may be a
  non-Nix (host) install. Add the needed sonames to `libraries` if you want them
  pinned to the prefix.
- `-isystem`, `-B` and `-L` are supplied by the wrapper; users do not pass
  `--sysroot`, `-L` or `-rpath` manually.
