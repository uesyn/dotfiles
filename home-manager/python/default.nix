{
  config,
  pkgs,
  ...
}:
{
  xdg.configFile = {
    "mise/conf.d/python.toml".text = ''
      [tools]
      python = "3.14.2"
    '';
  };
}
