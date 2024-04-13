{
  description = "Home Manager configuration of uesyn";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    flake-utils,
    nix-ld,
    nixos-wsl,
    neovim-nightly-overlay,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        currentUsername = builtins.getEnv "USER";
        currentHomeDirectory = builtins.getEnv "HOME";
        reActivationScript = pkgs.writeShellScript "build.sh" ''
          git config -f $HOME/.gitconfig.local credential.https://github.example.com.oauthClientId 0120e057bd645470c1ed
          git config -f $HOME/.gitconfig.local credential.https://github.example.com.oauthClientSecret 18867509d956965542b521a529a79bb883344c90
          git config -f $HOME/.gitconfig.local credential.https://github.example.com.oauthRedirectURL http://localhost/
        '';
        defaultBuild = pkgs.writeShellScript "buiild.sh" ''
          if [ -x "$(command -v nixos-rebuild)" ]; then
            sudo nixos-rebuild switch --flake github:uesyn/dotfiles#wsl2 --refresh --impure
          else
            nix run home-manager -- switch --flake github:uesyn/dotfiles --impure -b backup --refresh
          fi
        '';
        nixOSRebuild = pkgs.writeShellScript "buiild.sh" ''
          sudo nixos-rebuild switch --flake github:uesyn/dotfiles#wsl2 --refresh --impure
        '';
        hmRebuild = pkgs.writeShellScript "build.sh" ''
          nix run home-manager -- switch --flake github:uesyn/dotfiles --impure -b backup --refresh
        '';
      in {
        apps = {
          reactivate = {
            type = "app";
            program = "${reActivationScript}";
          };
          os = {
            type = "app";
            program = "${nixOSRebuild}";
          };
          hm = {
            type = "app";
            program = "${hmRebuild}";
          };
          default = {
            type = "app";
            program = "${defaultBuild}";
          };
        };

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
              nixpkgs.overlays = [neovim-nightly-overlay.overlay];
            }
          ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
          extraSpecialArgs = {
            inherit inputs;
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

              home-manager.nixosModules.home-manager
              {
                home-manager.backupFileExtension = "backup";
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.nixos = import ./home.nix;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                };
                nixpkgs.overlays = [neovim-nightly-overlay.overlay];
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
