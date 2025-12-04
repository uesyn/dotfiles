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

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-ai-tools,
      ...
    }@inputs:
    let
      # Utility functions
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Package configurations
      pkgsForSystem =
        {
          system,
          overlays ? [ ],
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
              opencode = nix-ai-tools.packages.${system}.opencode;
              droid = nix-ai-tools.packages.${system}.droid;
            })
          ];
        };

      # Application definitions
      appsForSystem =
        system:
        let
          pkgs = pkgsForSystem { inherit system; };
        in
        {
          hm = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "hm.sh" ''
              #!${pkgs.bash}/bin/bash
              ${pkgs.home-manager}/bin/home-manager switch --flake . --impure -b backup
            ''}/bin/hm.sh";
          };
        };

      # Library functions
      lib = {
        inherit pkgsForSystem;
        inherit forAllSystems;

        # Home Manager configuration helper
        hm =
          {
            system,
            user ? builtins.getEnv "USER",
            homeDirectory ? builtins.getEnv "HOME",
            modules ? [ ],
            overlays ? [ ],
            extraSpecialArgs ? { },
          }:
          let
            defaultArgs = {
              go = {
                private = [ ];
              };
              git = {
                user = "uesyn";
                email = "17411645+uesyn@users.noreply.github.com";
              };
              git-credential-oauth = {
                device = false;
                ghHosts = [ ];
              };
              crush = {
                providers = { };
              };
            };
          in
          home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsForSystem {
              inherit system;
              inherit overlays;
            };
            modules = [
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

      # Package definitions
      packagesForSystem = system: {
        homeConfigurations = {
          ${builtins.getEnv "USER"} = lib.hm {
            inherit system;
          };
          forecast = lib.hm {
            inherit system;
            user = "forecast";
            homeDirectory = "/tmp";
          };
        };
      };

      # Formatter configuration
      formatterForSystem = system: (pkgsForSystem { inherit system; }).nixfmt-tree;

    in
    {
      inherit lib;

      # Outputs organized by type
      apps = forAllSystems appsForSystem;
      packages = forAllSystems packagesForSystem;
      formatter = forAllSystems formatterForSystem;

      templates = {
        default = {
          path = ./templates;
          description = "dotfiles configuration";
        };
      };
    };
}
