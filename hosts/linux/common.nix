{pkgs, ...}: {
  system.stateVersion = "24.11";

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = "1048576";
    "fs.inotify.max_user_instances" = "8192";
  };

  programs = {
    zsh.enable = true;
    nix-ld.enable = true;
  };

  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    diffutils
    dig
    file
    git
    gnused
    gnutar
    iproute2
    procps
    pstree
    unzip
    vim
    wget
    wpa_supplicant
    wsl-open
    wslu
    xz
    zsh
  ];

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["nixos"];
      trusted-substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org"];
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
    };
  };
}
