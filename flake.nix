{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    myneovim.url = "github:uesyn/neovim";
    nix-ld.url = "github:Mic92/nix-ld";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
  };

  outputs = {
    nixpkgs,
    home-manager,
    flake-utils,
    nix-ld,
    nixos-wsl,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        # pin nixpkgs for tmux
        # To update rev, ref https://releases.nixos.org/nixpkgs/nixpkgs-24.11pre631646.e2dd4e18cc1c/git-revision
        nixpkgs-pinned = builtins.getFlake "github:NixOS/nixpkgs/e2dd4e18cc1c7314e24154331bae07df76eb582f";
        pkgs-pinned = nixpkgs-pinned.legacyPackages.${pkgs.system};
        overlays = [
          inputs.myneovim.overlays.default
          (final: prev: {
            tmux = pkgs-pinned.tmux;
            tmuxPlugins = pkgs-pinned.tmuxPlugins;
          })
        ];
        pkgs = import nixpkgs {
          inherit system;
          overlays = overlays;
        };
        currentUsername = builtins.getEnv "USER";
        currentHomeDirectory = builtins.getEnv "HOME";

        nixOSRebuild = pkgs.writeShellScriptBin "update-os" ''
          case "$1" in
            --help|-h)
              echo "Usage: update-os [--local|-l]"
              exit 0
              ;;
            --local|-l)
              if [[ ! -f "flake.nix" ]]; then
                echo "flake.nix not found"
                exit 1
              fi
              sudo nixos-rebuild switch --flake .#wsl2
              exit 0
              ;;
            "")
              sudo nixos-rebuild switch --flake github:uesyn/dotfiles#wsl2 --refresh --impure
              exit 0
              ;;
            *)
              echo "Invalid option: $1"
              exit 1
              ;;
          esac
        '';
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

            # extraSpecialArgs = {};
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
                programs.zsh.enable = true;
                programs.nix-ld = {
                  enable = true;
                  package = pkgs.nix-ld-rs;
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
                  zsh
                ];
                nix.package = pkgs.nixFlakes;
                nix.settings = {
                  experimental-features = ["nix-command" "flakes" "repl-flake"];
                  trusted-users = ["root" "nixos"];
                  trusted-substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org"];
                  substituters = ["https://nix-community.cachix.org"];
                  trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
                };
              }

              {
                environment.systemPackages = [
                  nixOSRebuild
                ];
              }
            ];
          };
        };

        formatter = pkgs.alejandra;
      }
    );
}
