{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.dotfiles.mise.tools = lib.mkOption {
    type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
    default = { };
    description = ''
      mise tools written to the global `config.toml` (the `mise use -g`
      target). Tool modules contribute their own entries as `lib.mkDefault`
      (Go from the go module, kubebuilder from the kubernetes module), so a
      plain definition here overrides them and a fresh machine only needs
      `mise install`.
    '';
    example = lib.literalExpression ''
      {
        go = "1.26";
      }
    '';
  };

  config = {
    # nono: mise installs toolchains under `~/.local/share/mise` and keeps
    # state under `~/.local/state/mise`; both are writable so `mise install`
    # and the Tool Sandbox exec grant work.
    dotfiles.nono.filesystem.allow = [
      "~/.local/share/mise"
      "~/.local/state/mise"
    ];
    # mise reads its settings from `~/.config/mise` (this replaces the nono
    # `mise_manager` group's read grant).
    dotfiles.nono.filesystem.read = [ "~/.config/mise" ];
    dotfiles.nono.filesystem.allowFile = [ "~/.mise.toml" ];

    xdg.configFile = {
      "mise/settings.toml".text = ''
        all_compile = false
        experimental = true

        [node]
        compile = false

        [python]
        compile = false
      '';
    };

    programs.mise = {
      package = pkgs.mise;
      enable = true;
      # Tools contributed through `dotfiles.mise.tools`; a fresh machine only
      # needs `mise install`.
      globalConfig = {
        tools = config.dotfiles.mise.tools;
      };
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = false;
    };

    home.sessionVariables = {
      MISE_ALL_COMPILE = "false";
      MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS = "python";
    };

    # Install the declared tools on every switch. Runs after `linkGeneration`
    # so the generated `~/.config/mise/config.toml` is already linked;
    # `mise install` is idempotent and skips tools that are already present.
    # It downloads from the network and extracts archives internally (no
    # external tar/gzip/xz), so the minimal activation PATH is enough.
    home.activation.miseInstall = lib.mkIf (config.dotfiles.mise.tools != { }) (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${lib.getExe pkgs.mise} install
      ''
    );
  };
}
