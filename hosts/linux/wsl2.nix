{pkgs, ...}: {
  wsl.enable = true;

  users = {
    users.nixos = {
      isNormalUser = true;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.zsh;
    };
    groups.docker = {};
  };

  virtualisation.docker.enable = true;
}
