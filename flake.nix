{
  description = "dotfiles configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    nix-ai-tools,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    aitoolsPkgsForSystem = {
      system,
    }:
      import nix-ai-tools {
        inherit system;
      };
    pkgsForSystem = {
      system,
      overlays ? [],
    }:
      import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = overlays ++ [
          (final: prev: {
            crush = nix-ai-tools.packages.${system}.crush;
            code = nix-ai-tools.packages.${system}.code;
            qwen-code = nix-ai-tools.packages.${system}.qwen-code;
          })
        ];
      };

    apps = forAllSystems (system: let
      pkgs = pkgsForSystem {inherit system;};
    in {
      hm = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "hm.sh" ''
          #!${pkgs.bash}/bin/bash
          ${pkgs.home-manager}/bin/home-manager switch --flake . --impure -b backup
        ''}/bin/hm.sh";
      };
    });

    lib = {
      inherit pkgsForSystem;
      inherit forAllSystems;
      hm = {
        system,
        user ? builtins.getEnv "USER",
        homeDirectory ? builtins.getEnv "HOME",
        modules ? [],
        overlays ? [],
        extraSpecialArgs ? {},
      }: let
        defaultArgs = {
          go = {
            private = [];
          };
          git = {
            user = "uesyn";
            email = "17411645+uesyn@users.noreply.github.com";
          };
          git-credential-oauth = {
            device = false;
            ghHosts = [];
          };
        };
      in
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsForSystem {
            inherit system;
            inherit overlays;
          };
          modules =
            [
              {
                home.username = user;
                home.homeDirectory = homeDirectory;
              }
              ./home-manager/default.nix
            ]
            ++ modules;
          extraSpecialArgs = nixpkgs.lib.attrsets.recursiveUpdate defaultArgs extraSpecialArgs;
        };
    };

    packages = forAllSystems (system: {
      homeConfigurations = {
        ${builtins.getEnv "USER"} = lib.hm {
          inherit system;
          # user = builtins.getEnv "USER";
          # homeDirectory = builtins.getEnv "HOME";
          # modules = [];
          # overlays = [];
          # extraSpecialArgs = {};
        };
      };
    });

    formatter = forAllSystems (system: (pkgsForSystem {inherit system;}).alejandra);
  in {
    inherit lib;
    inherit apps;
    inherit formatter;
    inherit packages;

    templates = {
      default = {
        path = ./templates;
        description = "dotfiles configuration";
      };
    };
  };
}
