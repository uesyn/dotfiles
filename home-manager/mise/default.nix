{
  pkgs,
  lib,
  config,
  ...
}:
{
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
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/share/mise/shims"
  ];

  home.sessionVariables = {
    MISE_ALL_COMPILE = "false";
    MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS = "python";
  };
}
