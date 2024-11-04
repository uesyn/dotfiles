{
  inputs,
  pkgs,
  gitUser,
  gitEmail,
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
    pkgs.ghq
  ];

  home.sessionVariables = {
    GIT_EDITOR = "nvim";
  };

  programs.gh = {
    enable = true;
    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
    };
    gitCredentialHelper.enable = false;
    extensions = [
      pkgs.gh-copilot
      pkgs.gh-dash
      pkgs.gh-poi
      pkgs.gh-s
    ];
  };

  programs.git = {
    enable = true;

    userName = gitUser;
    userEmail = gitEmail;

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
        "${pkgs.gh}/bin/gh auth git-credential"
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
