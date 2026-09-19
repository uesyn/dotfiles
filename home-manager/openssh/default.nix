{ pkgs, lib, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
in
{
  home.packages = [ pkgs.openssh ];

  # nono: OpenSSH execs helpers by absolute path (`ssh-sk-helper`,
  # `ssh-pkcs11-helper`, `ssh-keysign`) from its non-PATH `libexec`, so the
  # Linux outer exec gate must be told about that directory. macOS allows all
  # exec. `~/.ssh` stays denied by nono's `deny_credentials` group.
  dotfiles.nono.commandPolicies.executableDirs = lib.optionals isLinux [
    "${pkgs.openssh}/libexec"
  ];
}
