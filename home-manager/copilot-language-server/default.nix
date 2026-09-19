{ pkgs, ... }:
{
  home.packages = [ pkgs.copilot-language-server ];

  # nono: the Copilot LSP stores auth/cache under `~/.config/github-copilot`
  # (read+write, so sign-in and token refresh work inside the sandbox). The
  # Node interpreter comes from the wrapper's `exec`, which the exec gate adds.
  dotfiles.nono.filesystem.allow = [ "~/.config/github-copilot" ];
}
