{
  lib,
  buildNpmPackage,
  importNpmLock,
  makeWrapper,
  nerd-fonts,
  nodejs,
  src,
}:
let
  package = lib.importJSON (src + "/package.json");
  nerdMono = nerd-fonts.jetbrains-mono;
  nerdMonoDir = "${nerdMono}/share/fonts/truetype/NerdFonts/JetBrainsMono";
in
buildNpmPackage {
  pname = "pi-web";
  inherit (package) version;
  inherit src nodejs;
  npmDeps = importNpmLock { npmRoot = src; };
  inherit (importNpmLock) npmConfigHook;
  nativeBuildInputs = [ makeWrapper ];
  npmInstallFlags = [ "--ignore-scripts" ];
  env.NEXT_TELEMETRY_DISABLED = "1";

  patches = [ ./pi-web-nix.patch ];
  postPatch = ''
    cp ${nerdMonoDir}/JetBrainsMonoNerdFontMono-{Regular,Bold}.ttf app/
    cp ${./pi-web-runtime.cjs} bin/nix-runtime.cjs
  '';

  postBuild = ''
    node bin/prepare-terminal.js
    rm -rf .next/cache
    find .next -name '*.js.map' -delete
  '';

  postInstall = ''
    mkdir -p "$out/share/licenses/pi-web"
    tar -xOf ${nerdMono.src} OFL.txt > "$out/share/licenses/pi-web/JetBrainsMono-Nerd-Font-OFL.txt"
    wrapProgram "$out/bin/pi-web" --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set PI_WEB_SKIP_VERSION_CHECK 1
  '';

  meta = {
    description = "Web UI for the Pi coding agent";
    homepage = "https://github.com/agegr/pi-web";
    license = with lib.licenses; [ mit ofl ];
    mainProgram = "pi-web";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
