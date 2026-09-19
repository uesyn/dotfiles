{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ./commands ];

  options.dotfiles.nono = {
    aliasPrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Prefix for the generated shell aliases. Defaults to `""`, so the nono
        wrappers take over the plain command names. The fence wrappers stay
        reachable via `dotfiles.fence.aliasPrefix` (default `"fence-"`).
      '';
    };
    wrap = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Commands to wrap with nono. Each entry creates a shell alias named
        `<aliasPrefix><command>` in both zsh and bash that runs
        `nono run --profile agents -s --allow-cwd -- <command>`. Tool modules
        add themselves here (e.g. the OpenCode and Pi modules), so a command
        can be un-wrapped only with `lib.mkForce`.
      '';
      example = lib.literalExpression ''[ "opencode" "pi" ]'';
    };
    # The `filesystem.*` lists are the profile's `filesystem.*` arrays. The
    # nono module's own `config` defines the core policy through these options,
    # so a module setting one *appends* to the core (list options concatenate)
    # and `config.dotfiles.nono.filesystem.*` holds the merged list.
    filesystem = {
      read = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Directories appended to `filesystem.read` (read-only, recursive).
          For a single file use `readFile`.
        '';
      };
      readFile = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Single files appended to `filesystem.read_file` (read-only). Use
          this for one file whose parent directory should stay hidden.
        '';
      };
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Directories appended to `filesystem.allow` (read-write). On Linux a
          path denied below this directory would make the sandbox refuse to
          start, so keep grants scoped to the paths that are actually needed.
        '';
      };
      allowFile = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Single files appended to `filesystem.allow_file` (read-write). Use
          this for files whose parent directory should stay read-only or hidden
          (e.g. files reached through a symlink).
        '';
      };
      unixSocket = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          AF_UNIX sockets appended to `filesystem.unix_socket` (connect-only;
          implies read access on the socket path). The Docker module adds the
          Docker sockets here (`/var/run/docker.sock` on Linux, the Colima
          sockets on macOS).
        '';
      };
      deny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Paths appended to `filesystem.deny`. On Linux a deny nested below an
          allowed parent is rejected by Landlock, so denied paths must not sit
          inside the read/allow lists.
        '';
      };
      bypassProtection = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Paths appended to `filesystem.bypass_protection` (hardlink/symlink
          protection is relaxed there).
        '';
      };
    };
    commandPolicies.executableDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Directories appended to `command_policies.executable_dirs`
        (the openssh, man, docker, autoconf and build-essential modules each
        add their own). On Linux, Tool Sandbox's outer exec gate only allows
        executables found by scanning the non-writable `PATH` directories plus
        these dirs, so any other toolchain that execs helpers by absolute path
        needs its helper directory added here. Entries must exist and must not
        be writable by the sandbox.
      '';
    };
    commandPolicies.commands = lib.mkOption {
      type = lib.types.attrsOf (lib.types.functionTo lib.types.attrs);
      default = { };
      description = ''
        Per-command invocation policies and sandboxes, rendered into
        `command_policies.commands`. Each value is a function of `pkgs` so a
        command can build its `executable` path (e.g. `pkgs: { executable =
        "${pkgs.gh}/bin/.gh-wrapped"; ...; }`); the nono module applies each
        with its own `pkgs`. The gh/git guardrails live in
        `home-manager/nono/commands/` (kept in the nono module as a single
        security unit); other modules can add their own command sandboxes.
      '';
    };
  };

  config =
    let
      nono = config.dotfiles.nono;

      # Fixed profile name; the alias wrappers and the rendered file name use
      # it, so `nono run --profile agents` works out of the box.
      profileName = "agents";

      wrappedAliases = lib.listToAttrs (
        map (cmd: {
          name = "${nono.aliasPrefix}${cmd}";
          value = "nono run --profile ${profileName} -s --allow-cwd -- ${cmd}";
        }) nono.wrap
      );

      profile = {
        extends = "default";
        # `nix_runtime` covers /nix/store and the nix profile paths, so the
        # session does not need a blanket read grant on all of /nix. The
        # per-toolchain `*_runtime` groups were dropped: the owning modules now
        # grant the runtime homes via `dotfiles.nono.filesystem.allow`.
        groups = {
          include = [ "nix_runtime" ];
        };
        workdir = {
          access = "readwrite";
        };
        filesystem = {
          read = nono.filesystem.read;
          read_file = nono.filesystem.readFile;
          allow = nono.filesystem.allow;
          allow_file = nono.filesystem.allowFile;
          unix_socket = nono.filesystem.unixSocket;
          deny = nono.filesystem.deny;
          bypass_protection = nono.filesystem.bypassProtection;
        };
        network = {
          block = false;
        };

        command_policies = {
          # Core helper dirs plus `commandPolicies.executableDirs`; used by
          # toolchains that re-exec helpers by absolute path.
          executable_dirs = nono.commandPolicies.executableDirs;
          # pi-undo selects its private gitdir with GIT_DIR/GIT_WORK_TREE.
          # pi spawns git directly (caller `session`) and the tool sandbox
          # strips GIT_* by default, so forward those two from the session.
          session_export_env = [
            "GIT_DIR"
            "GIT_WORK_TREE"
          ];
          # gh/git command policies (guardrails) are contributed by the
          # `commands/` submodule; each value is a function of `pkgs`.
          commands = lib.mapAttrs (_: f: f pkgs) nono.commandPolicies.commands;
        };
      };
    in
    {
      # Core sandbox policy. The owning module contributes tool-specific
      # entries by setting these same options (list options concatenate), so
      # the rendered profile is `core ++ <module contributions>`.
      dotfiles.nono = {
        filesystem = {
          # Only the agent workspace/scratch paths and the few unowned stores
          # stay here; tool-owned paths (runtime homes, tool config/data dirs)
          # are contributed by their modules through these same options.
          read = [
            # Nix CLI config (no dedicated module).
            "~/.config/nix"
          ];
          allow = [
            "~/bin"
            "~/pkg"
            "~/src"
            "/tmp"
            "~/.cache"
            # Home Manager / Nix state (no dedicated module).
            "~/.local/state/home-manager"
            "~/.local/state/nix"
          ];
        };
      };

      home.packages = [
        pkgs.llm-agents.nono
      ];

      programs.zsh.shellAliases = wrappedAliases;
      programs.bash.shellAliases = wrappedAliases;

      xdg.configFile."nono/profiles/${profileName}.json".text = builtins.toJSON profile;
    };
}
