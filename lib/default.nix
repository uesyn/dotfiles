{
  nixpkgs,
  nixpkgs-unstable,
  home-manager,
  nixos-wsl,
}: let
  defaultOverlays = [
    (final: prev: {
      unstable = import nixpkgs-unstable {
        system = "${prev.system}";
        config = {
          allowUnfree = true;
        };
      };
    })
  ];

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
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = overlays ++ defaultOverlays;
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

  # TODO: accept extraSpecialArgs
  nixos = {
    system,
    overlays ? [],
    modules ? [],
  }: nixpkgs.lib.nixosSystem {
    inherit system;
    modules =
      [
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = overlays ++ defaultOverlays;
        }
        ./nixos/common.nix
      ]
      ++ modules;
  };

  # For nixos running on wsl2
  wsl2 = {
    system,
    overlays ? [],
    modules ? [],
  }: nixos {
    inherit system;
    inherit overlays;
    modules =
      modules
      ++ [
        nixos-wsl.nixosModules.default
        ./nixos/wsl2.nix
      ];
  };
in
{
  inherit hm;
  inherit nixos;
  inherit wsl2;
}
