{
  inputs,
  pkgs,
  ...
}: let
  git-credential-oauth-wrapper = pkgs.writeShellScriptBin "git-credential-oauth-wrapper" ''
    if [ -n "$REMOTE" ] || [ -n "$SSH_CLIENT" ]; then
      exec ${pkgs.git-credential-oauth}/bin/git-credential-oauth -device "$@"
    else
      exec ${pkgs.git-credential-oauth}/bin/git-credential-oauth "$@"
    fi
  '';
in {
  home.packages = [
    git-credential-oauth-wrapper
    pkgs.gh
    pkgs.gh-copilot
    pkgs.gh-dash
    pkgs.gh-poi
    pkgs.ghq
    pkgs.gh-s
  ];

  home.sessionVariables = {
    GIT_EDITOR = "nvim";
  };

  programs.git = {
    enable = true;

    userName = "uesyn";
    userEmail = "17411645+uesyn@users.noreply.github.com";

    ignores = [
      ".DS_Store"
      ".vim-lsp-settings"
      "venv"
      ".venv"
      "mise.toml"
      ".mise.toml"
    ];

    includes = [
      {path = "~/.gitconfig.local";}
    ];

    hooks = {
      pre-commit = ./hooks/pre-commit;
      pre-push = ./hooks/pre-push;
    };

    extraConfig = {
      ghq.root = "~/src";

      credential.helper = [
        ""
        "cache --timeout=86400"
        "oauth-wrapper"
      ];

      url = {
        "https://github.com/" = {
          insteadOf = "git@github.com:";
        };
      };

      pull.ff = "only";
      feature.manyFiles = true;
      init.defaultBranch = "main";
      index.skipHash = false;
      rebase.updateRefs = true;
      push.autoSetupRemote = true;
    };
  };
}
