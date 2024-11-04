{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    nix-ld = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/nix-ld";
    };
    nixos-wsl = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/NixOS-WSL";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    flake-utils,
    nix-ld,
    nixos-wsl,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        # pin nixpkgs for tmux
        # To update rev, ref https://releases.nixos.org/nixpkgs/nixpkgs-24.11pre631646.e2dd4e18cc1c/git-revision
        # nixpkgs-pinned = builtins.getFlake "github:NixOS/nixpkgs/e2dd4e18cc1c7314e24154331bae07df76eb582f";
        # pkgs-pinned = nixpkgs-pinned.legacyPackages.${pkgs.system};
        overlays = [
          # inputs.myneovim.overlays.default
          # (final: prev: {
          #   tmux = pkgs-pinned.tmux;
          #   tmuxPlugins = pkgs-pinned.tmuxPlugins;
          # })
        ];
        pkgs = import nixpkgs {
          inherit system;
          config = {allowUnfree = true;};
          overlays = overlays;
        };
        currentUsername = builtins.getEnv "USER";
        currentHomeDirectory = builtins.getEnv "HOME";
      in {
        # For standalone home-manager
        packages.homeConfigurations = {
          "${currentUsername}" = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            modules = [
              ./home.nix
              {
                home.username = currentUsername;
                home.homeDirectory = currentHomeDirectory;
              }
            ];

            extraSpecialArgs = {
              gitUser = "uesyn";
              gitEmail = "17411645+uesyn@users.noreply.github.com";
              gitHosts = [];
            };
          };
        };

        # For nixos running on wsl2
        packages.nixosConfigurations = {
          wsl2 = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              nix-ld.nixosModules.nix-ld
              nixos-wsl.nixosModules.default
              {
                wsl.enable = true;
                system.stateVersion = "24.05";
                users = {
                  users.nixos = {
                    extraGroups = ["wheel" "docker"];
                    shell = pkgs.zsh;
                  };
                  groups.docker = {};
                };
                virtualisation.docker.enable = true;
                programs.nix-ld = {
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
                nix.package = pkgs.nixVersions.stable;
                nix.settings = {
                  experimental-features = ["nix-command" "flakes"];
                  trusted-users = ["root" "nixos"];
                  trusted-substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org"];
                  substituters = ["https://nix-community.cachix.org"];
                  trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
                };
              }
            ];
          };
        };

        formatter = pkgs.alejandra;
      }
    );
}
