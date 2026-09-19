{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dotfiles.buildEssential;

  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  # Fixed toolchain; not user-configurable. `gcc` / `cc` are wrappers around
  # this unwrapped driver and the nono profile grants its libexec helpers
  # (`cc1`, `collect2`) exec.
  gccUnwrapped = pkgs.gcc-unwrapped;

  # ELF interpreter basename for the host target. nixpkgs already encodes the
  # per-target loader path (`stdenv.cc.bintools.dynamicLinker`, e.g.
  # `${glibc}/lib/ld-linux-x86-64.so.2`); only the basename is embedded, with the
  # store path replaced by the stable `$RUNTIME/lib`. Only `x86_64` and
  # `aarch64` are supported, where this is a concrete name (no glob/empty).
  dynamicLinker = baseNameOf pkgs.stdenv.cc.bintools.dynamicLinker;

  # Fixed stable prefix; not user-configurable. `$HOME/.local/nix-runtime`.
  runtimePrefix = "${config.home.homeDirectory}/.local/nix-runtime";

  # Every directory name below is a stable alias under $RUNTIME, never a store
  # path, so generated ELF files do not embed /nix/store/<hash>.
  runtimeLib = "${runtimePrefix}/lib";
  runtimeGccLib = "${runtimePrefix}/gcc-lib";
  runtimeInclude = "${runtimePrefix}/include";

  # The runtime tree is a single store derivation that symlinks the current
  # glibc / libgcc / headers. Home Manager symlinks $RUNTIME at this derivation,
  # which makes the whole closure a GC root while keeping the ELF-visible path
  # stable across toolchain updates.
  runtimeTree = pkgs.runCommand "nix-runtime-${gccUnwrapped.version}" { } ''
    mkdir -p "$out/lib" "$out/gcc-lib" "$out/include"

    # glibc runtime: loader, libc, crt*.o, and the libc.so linker script.
    for f in ${pkgs.glibc}/lib/*; do
      ln -s "$f" "$out/lib/"
    done

    # glibc also ships the loader (and a few compat objects) under lib64 on
    # multiarch systems. Expose it too so `$RUNTIME/lib64/ld-linux-*.so*`
    # resolves for tools that look there; the wrappers keep using `lib/`.
    if [ -d ${pkgs.glibc}/lib64 ]; then
      mkdir -p "$out/lib64"
      for f in ${pkgs.glibc}/lib64/*; do
        ln -s "$f" "$out/lib64/"
      done
    fi

    # Make sure the dynamic loader is reachable from `lib/` (where the
    # wrappers point `--dynamic-linker`) even on layouts that install it only
    # under lib64.
    for loader in ${pkgs.glibc}/lib64/ld-linux-*.so* ${pkgs.glibc}/lib/ld-linux-*.so*; do
      [ -e "$loader" ] || continue
      ln -sf "$loader" "$out/lib/"
    done

    # GCC runtime: libgcc_s, libstdc++, sanitizers, ...
    for f in ${lib.getLib gccUnwrapped}/lib/*; do
      ln -s "$f" "$out/gcc-lib/"
    done

    # glibc development headers. GCC's own builtin headers stay in its store
    # output and are not copied here.
    for f in ${lib.getDev pkgs.glibc}/include/*; do
      ln -s "$f" "$out/include/"
    done

    # Extra libraries, if any. Name collisions fail the build instead of
    # silently shadowing an earlier library.
    ${lib.concatMapStringsSep "\n" (p: ''
      if [ -d ${lib.getLib p}/lib ]; then
        for f in ${lib.getLib p}/lib/*; do
          ln -s "$f" "$out/lib/"
        done
      fi
      if [ -d ${lib.getDev p}/include ]; then
        for f in ${lib.getDev p}/include/*; do
          ln -s "$f" "$out/include/"
        done
      fi
    '') cfg.libraries}
  '';

  # Link-time and run-time flags shared by gcc/cc/g++/c++: search the prefix
  # first, and record only the stable prefix in RUNPATH / PT_INTERP.
  compileFlags = [
    "-B${runtimeLib}/"
    "-B${runtimeGccLib}/"
    # Force the raw binutils `as`/`ld` regardless of PATH order; the wrapped
    # binutils `ld` would inject store paths into RUNPATH.
    "-B${lib.getBin pkgs.binutils-unwrapped}/bin/"
    "-isystem"
    runtimeInclude
    "-L${runtimeGccLib}"
    "-L${runtimeLib}"
    "-Wl,-rpath,${runtimeGccLib}"
    "-Wl,-rpath,${runtimeLib}"
    "-Wl,--dynamic-linker=${runtimeLib}/${dynamicLinker}"
  ];

  # Compilers go through gcc-unwrapped; the flags above replace the store paths
  # that nixpkgs' cc-wrapper would otherwise bake in.
  mkCompileWrapper =
    name: compiler:
    pkgs.writeShellScriptBin name ''
      exec ${lib.getExe' gccUnwrapped compiler} \
        ${lib.escapeShellArgs compileFlags} \
        "$@"
    '';

  # Helpers that do not link (gcc-ar, gcov, ...) only need to reach the
  # unwrapped driver; `as` / `ld` come from `binutils-unwrapped` on PATH, not
  # the nixpkgs binutils wrapper (whose `ld` injects store paths into RUNPATH).
  mkExecWrapper =
    name: prog:
    pkgs.writeShellScriptBin name ''
      exec ${lib.getExe' gccUnwrapped prog} "$@"
    '';

  # The preprocessor only needs the stable headers, not the linker flags.
  mkCppWrapper =
    name:
    pkgs.writeShellScriptBin name ''
      exec ${lib.getExe' gccUnwrapped "cpp"} -isystem ${runtimeInclude} "$@"
    '';

  # gcc-unwrapped bin entries re-exposed verbatim (no link step involved).
  plainTools = [
    "gcc-ar"
    "gcc-nm"
    "gcc-ranlib"
    "gcov"
    "gcov-dump"
    "gcov-tool"
    "lto-dump"
  ];

  compilerPackages = [
    (mkCompileWrapper "gcc" "gcc")
    (mkCompileWrapper "cc" "gcc")
    (mkCompileWrapper "g++" "g++")
    (mkCompileWrapper "c++" "g++")
    (mkCppWrapper "cpp")
  ]
  ++ map (prog: mkExecWrapper prog prog) plainTools;
in
{
  options.dotfiles.buildEssential = {
    libraries = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Extra packages whose libraries (and headers, when present) are exposed
        from the prefix (`$RUNTIME/lib`, `$RUNTIME/include`) and put on the
        wrappers' `-L` / `-rpath` path. Library file name collisions fail the
        build rather than silently shadowing an earlier library.
      '';
      example = lib.literalExpression "[ pkgs.zlib pkgs.openssl ]";
    };
  };

  config = lib.mkIf isLinux {
    # One symlink for the whole prefix: Home Manager swaps it atomically on
    # update/rollback, and referencing the derivation keeps the closure rooted
    # against GC.
    home.file."${lib.removePrefix "${config.home.homeDirectory}/" runtimePrefix}".source = runtimeTree;

    home.packages = compilerPackages ++ [ pkgs.binutils-unwrapped ];

    # nono: read the prefix (the loader follows its symlinks into the store),
    # allow exec of the loader through the stable prefix instead of a
    # store-hash-specific glibc directory, and grant GCC's PATH-external
    # helpers (`cc1`, `collect2`) from the fixed unwrapped driver.
    dotfiles.nono.filesystem.read = [ runtimePrefix ];
    dotfiles.nono.commandPolicies.executableDirs = [
      runtimeLib
      "${gccUnwrapped}/libexec/gcc/${pkgs.stdenv.hostPlatform.config}/${gccUnwrapped.version}"
    ];
  };
}
