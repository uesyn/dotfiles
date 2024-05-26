{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-pinned.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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
        pkgs = nixpkgs.legacyPackages.${system};
        currentUsername = builtins.getEnv "USER";
        currentHomeDirectory = builtins.getEnv "HOME";
        nixOSRebuild = pkgs.writeShellScriptBin "update-env" ''
          sudo nixos-rebuild switch --flake github:uesyn/dotfiles#wsl2 --refresh --impure
        '';
        hmRebuild = pkgs.writeShellScriptBin "update-env" ''
          nix run home-manager -- switch --flake github:uesyn/dotfiles --impure -b backup --refresh
        '';
        overlays = [
          inputs.myneovim.overlays.default
        ];
        hmExtraSpecialArgs = {
          inherit inputs;
        };
      in {
        # For standalone home-manager
        packages.homeConfigurations."${currentUsername}" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          # Specify your home configuration modules here, for example,
          # the path to your home.nix.
          modules = [
            ./home.nix
            {
              home.username = currentUsername;
              home.homeDirectory = currentHomeDirectory;
              home.packages = [
                hmRebuild
              ];
              nixpkgs.overlays = overlays;
            }
          ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
          extraSpecialArgs = hmExtraSpecialArgs;
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

              home-manager.nixosModules.home-manager
              {
                home-manager.backupFileExtension = "backup";
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.nixos = import ./home.nix;
                home-manager.extraSpecialArgs = hmExtraSpecialArgs;
                nixpkgs.overlays = overlays;
              }
            ];
          };
        };

        devShells = let
          shellHookBase = ''
            export SHELL=${pkgs.lib.getExe pkgs.zsh}
            exec $SHELL
          '';
        in {
          gcloud = pkgs.mkShell {
            packages = [
              pkgs.google-cloud-sdk
            ];
            shellHook = shellHookBase;
          };

          python = pkgs.mkShell {
            packages = [
              pkgs.python312Full
              pkgs.python312Packages.pip
              pkgs.nodePackages.pyright
            ];
            shellHook = shellHookBase;
          };

          python311 = pkgs.mkShell {
            packages = [
              pkgs.python311Full
              pkgs.python311Packages.pip
              pkgs.nodePackages.pyright
            ];
            shellHook = shellHookBase;
          };

          go121 = pkgs.mkShell {
            packages = [
              pkgs.go_1_21
            ];
            shellHook = shellHookBase;
          };
        };

        formatter = pkgs.alejandra;
      }
    );
}
