{ pkgs, lib, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  home.packages = [
    pkgs.docker-buildx
    pkgs.docker-client
  ]
  ++ lib.optionals isDarwin [
    # macOS runs Docker through Colima; the credential helpers are macOS-only.
    pkgs.colima
    pkgs.docker-credential-helpers
  ];

  # nono: the Docker client reaches dockerd over a UNIX socket and execs
  # helpers by absolute path, so the sandbox needs the socket plus the
  # non-PATH helper dirs (see `home-manager/nono/default.nix`).
  dotfiles.nono.filesystem.unixSocket =
    if isLinux then
      [ "/var/run/docker.sock" ]
    else
      [
        # macOS runs Colima, whose per-profile sockets live under the home
        # directory. `fence` lists the same sockets, but the two sandboxes are
        # intentionally independent (no shared source); keep them in sync by
        # hand if Colima's paths change.
        "~/.colima/docker.sock"
        "~/.colima/default/docker.sock"
        "~/.config/colima/docker.sock"
      ];

  dotfiles.nono.filesystem.allow = [ "~/.docker" ];
  dotfiles.nono.filesystem.bypassProtection = [ "~/.docker" ];

  # docker-client's `bin/docker` is a small C launcher that execs the real CLI
  # from `libexec/docker`, which is not on PATH. `docker buildx` needs nothing
  # (its `~/.nix-profile/bin` symlink resolves to the plugin binary), but
  # `docker compose` is only reached through `DOCKER_CLI_PLUGIN_DIRS`; this
  # plugin dir grants that without exposing a standalone `docker-compose`
  # command. Entries are exec-allowlist only on Linux; macOS allows all exec.
  dotfiles.nono.commandPolicies.executableDirs = lib.optionals isLinux [
    "${pkgs.docker-client}/libexec/docker"
    "${pkgs.docker-compose}/libexec/docker/cli-plugins"
  ];
}
