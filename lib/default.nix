{
  nixpkgs,
  home-manager,
}: let
  pkgsForSystem = {
    system,
    overlays ? [],
  }:
    import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
      overlays = overlays;
    };

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

  forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
in {
  inherit pkgsForSystem;
  inherit hm;
  inherit forAllSystems;
}
