{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    git-credential-oauth
  ];

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
        "cache --timeout=86400"
        "oauth"
        "env"
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
