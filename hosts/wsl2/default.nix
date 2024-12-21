{
  pkgs,
  extraSpecialArgs,
  ...
}: {
  system.stateVersion = "24.11";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.nixos = import ../../home-manager;
  home-manager.users.uesyn = import ../../home-manager;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = extraSpecialArgs;

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = "1048576";
    "fs.inotify.max_user_instances" = "8192";
  };

  users = {
    users.nixos = {
      isNormalUser = true;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.zsh;
    };
    users.uesyn = {
      isNormalUser = true;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.zsh;
    };
    groups.docker = {};
  };
  virtualisation.docker.enable = true;

  programs = {
    zsh.enable = true;
    nix-ld = {
      dev.enable = true;
      libraries = with pkgs; [
        zlib
        zstd
        stdenv.cc.cc
        curl
        openssl
        attr
        libssh
        bzip2
        libxml2
        acl
        libsodium
        util-linux
        xz
        systemd
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    dig
    git
    vim
    wsl-open
    wslu
    zsh
  ];

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "nixos"];
      trusted-substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org"];
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
    };
  };
}
