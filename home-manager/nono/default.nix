{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.nono = {
    profileName = lib.mkOption {
      type = lib.types.str;
      default = "agents";
      description = "nono profile name, written to ~/.config/nono/profiles/<name>.json.";
    };
    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "*" ];
      description = "Allowed domains for network access in nono.";
    };
    aliasPrefix = lib.mkOption {
      type = lib.types.str;
      default = "nono-";
      description = ''
        Prefix for the generated shell aliases. The default keeps them from
        colliding with the fence wrappers of the same commands. Set to `""`
        to take over the plain command names; remove those commands from
        `dotfiles.fence.wrap` first or Home Manager fails with a conflicting
        definition.
      '';
    };
    wrap = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "opencode"
        "pi"
      ];
      description = ''
        Commands to wrap with nono. Each entry creates a shell alias of the
        same name in both zsh and bash (prefixed with `aliasPrefix`) that runs
        `nono run --profile <profileName> -- <command>`.
      '';
      example = lib.literalExpression ''[ "opencode" "pi" ]'';
    };
    extraReads = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra filesystem paths to grant read-only access inside the sandbox.";
    };
  };

  config =
    let
      nono = config.dotfiles.nono;

      wrappedAliases = lib.listToAttrs (
        map (cmd: {
          name = "${nono.aliasPrefix}${cmd}";
          value = "nono run --profile ${nono.profileName} -- ${cmd}";
        }) nono.wrap
      );

      # Converted from ~/.config/fence/fence.json.
      #
      # fence -> nono mapping:
      #   filesystem.allowRead   -> filesystem.read
      #   filesystem.allowWrite  -> filesystem.allow (read+write; nono needs
      #                             read access to use a writable tree)
      #   network.allowedDomains -> network.allow_domain
      #   network.deniedDomains  -> network.deny_domain
      #   command.deny           -> no equivalent (see below)
      #
      # fence's `dir/**` write globs become literal directories so files
      # created after sandbox start are also covered; only the read glob for
      # zsh completion dumps is kept as a glob.
      #
      # fence `denyRead` entries already covered by the `default` profile's
      # deny groups (~/.ssh, ~/.gnupg, ~/.aws, ~/.kube, ~/.netrc,
      # ~/.git-credentials, ~/.config/gcloud, ...) are not repeated; only the
      # paths fence denied that nono does not deny by default are listed.
      #
      # fence's command.deny is prefix-based (`git push`, `gh pr create`) and
      # nono's command_policies match whole binaries, so it is not converted.
      # The default `dangerous_commands` group still blocks rm/sudo/pip/npm
      # and friends for commands the wrapped agent spawns.
      profile = {
        extends = "default";
        meta = {
          name = nono.profileName;
          description = "Converted from ~/.config/fence/fence.json";
        };
        workdir.access = "readwrite";
        filesystem = {
          read = [ "/nix" ] ++ nono.extraReads;
          allow = [
            "~/pkg"
            "~/bin"
            "/tmp"
            "~/.cache"
            "~/.pi"
            "~/.opencode"
            # ~/.local/state itself is a parent of nono's protected state root
            # (~/.local/state/nono) and is rejected on Linux, so grant the
            # tool state directories individually. macOS adds the broad grant
            # in the platform override below (Seatbelt can deny the root).
            "~/.local/state/opencode"
            "~/.local/state/pi"
            "~/.local/state/mise"
            "~/.docker"
            "~/.npm/_cacache"
            "~/.npm/_npx"
            "~/.bun"
            "~/.cargo/registry"
            "~/.cargo/git"
            "~/.zcompdump*"
            "~/.local/share"
          ];
          allow_file = [ "~/.cargo/.package-cache" ];
          deny = [
            "~/.pypirc"
            "~/.cargo/credentials"
            "~/.cargo/credentials.toml"
          ];
          # deny_credentials denies ~/.docker, so the grant above needs the
          # deny lifted explicitly (and the relaxation is reported on start).
          bypass_protection = [ "~/.docker" ];
        };
        network = {
          allow_domain = nono.allowedDomains;
          deny_domain = [
            "169.254.169.254"
            "metadata.google.internal"
            "instance-data.ec2.internal"
            "statsig.anthropic.com"
            "*.sentry.io"
          ];
        };
        # Landlock cannot express deny-within-allow, so Linux cannot grant
        # all of ~/.config while keeping the default denies under it
        # (~/.config/gcloud, browser profiles, ~/.config/op, ...). macOS
        # Seatbelt can, so the broad grant stays macOS-only and Linux gets a
        # narrow list of agent config directories instead.
        platform_overrides = {
          macos = {
            # Seatbelt can deny nono's own state root inside an allowed
            # parent, so keep fence's broad grants here.
            allow_parent_of_protected = true;
            filesystem.read = [ "~/.config" ];
            filesystem.allow = [ "~/.local/state" ];
          };
          linux.filesystem.read = [
            "~/.config/opencode"
            "~/.config/github-copilot"
            "~/.config/gh"
            "~/.config/git"
            "~/.config/mise"
          ];
        };
      };
    in
    {
      home.packages = [
        pkgs.llm-agents.nono
      ];

      programs.zsh.shellAliases = wrappedAliases;
      programs.bash.shellAliases = wrappedAliases;

      xdg.configFile."nono/profiles/${nono.profileName}.json".text = builtins.toJSON profile;
    };
}
