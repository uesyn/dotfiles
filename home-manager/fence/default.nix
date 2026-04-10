{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  config =
    {
      home.packages = [
        pkgs.fence
      ];
    };
}
