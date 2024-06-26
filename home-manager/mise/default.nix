{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    mise
  ];
  home.file = {
    ".config/mise/settings.toml".text = ''
      experimental = true
    '';
  };
}
