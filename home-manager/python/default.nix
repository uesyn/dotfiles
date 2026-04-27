{
  config,
  pkgs,
  ...
}:
{
  config = {
    home.packages = [
      pkgs.python315
    ];
  };
}
