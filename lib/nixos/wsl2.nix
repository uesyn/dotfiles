{pkgs, ...}: {
  wsl.enable = true;
  wsl.useWindowsDriver = true;

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
