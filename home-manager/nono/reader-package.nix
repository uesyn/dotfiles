# Opt-in Linux ELF metadata reads; retain the upstream parsing functions.
{
  nono,
  python3,
  stdenv,
}:
nono.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./elf-reader.patch ];
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ python3 ];
  prePatch = (old.prePatch or "") + ''
    cp crates/nono-cli/src/tool-sandbox/platform/linux.rs elf-reader-upstream.rs
  '';
  postPatch = (old.postPatch or "") + ''
    cp ${./elf-reader.rs} crates/nono-cli/src/tool-sandbox/platform/elf_reader.rs
    cp ${./elf-reader-tests.rs} crates/nono-cli/src/tool-sandbox/platform/elf-reader-tests.rs
  '';
  # Compile the actual patched parser plus its I/O helper independently, rather
  # than rebuilding nono's entire test executable and dependencies with unwind/LTO.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python3}/bin/python3 ${./test-elf-reader.py} \
      --source elf-reader-upstream.rs \
      --reader crates/nono-cli/src/tool-sandbox/platform/elf_reader.rs \
      --patch ${./elf-reader.patch} \
      --corpus target/${stdenv.hostPlatform.rust.rustcTarget}/release/nono \
      --corpus ${nono}/bin/nono
    runHook postCheck
  '';
})
