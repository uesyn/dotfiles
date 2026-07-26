{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  options.dotfiles.fence = {
    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "*" ];
      description = "Allowed domains for network access in fence.";
    };
    allowedUnixSockets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Allowed unix sockets for network access in fence.";
    };
    deniedCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Denied commands for fence command policy.";
    };
    wrap = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "opencode" ];
      description = ''
        Commands to wrap with fence. Each entry creates a shell alias of the
        same name in both zsh and bash. When `allowedDomains` contains `"*"`,
        the wrapper additionally unsets `HTTP_PROXY` / `HTTPS_PROXY` /
        `ALL_PROXY` (and lowercase variants) so the wrapped command makes
        direct connections that fence can permit.
      '';
      example = lib.literalExpression ''[ "opencode" "claude" ]'';
    };
  };

  config =
    let
      isLinux = pkgs.stdenv.hostPlatform.isLinux;

      allowedDomains = builtins.toJSON config.dotfiles.fence.allowedDomains;

      # macOS only (Colima)
      colimaSockets = lib.optionals (!isLinux) [
        "~/.colima/docker.sock"
        "~/.colima/default/docker.sock"
        "~/.config/colima/docker.sock"
      ];
      allowedUnixSockets = builtins.toJSON (
        lib.unique (colimaSockets ++ config.dotfiles.fence.allowedUnixSockets)
      );

      baseDeniedCommands = [
        # Git commands that modify remote state
        "git push"
        "git reset"
        "git clean"
        "git checkout --"
        "git rebase"
        "git merge"

        # Package publishing
        "npm publish"
        "pnpm publish"
        "yarn publish"
        "cargo publish"
        "twine upload"
        "gem push"

        # Privilege escalation
        "sudo"

        # GitHub CLI (remote-mutating)
        "gh pr create"
        "gh pr merge"
        "gh pr close"
        "gh pr reopen"
        "gh pr review"
        "gh pr comment"
        "gh release create"
        "gh release delete"
        "gh repo create"
        "gh repo fork"
        "gh repo delete"
        "gh issue create"
        "gh issue close"
        "gh issue comment"
        "gh gist create"
        "gh workflow run"
        "gh api"
        "gh auth login"
        "gh secret set"
        "gh secret delete"
        "gh variable set"
        "gh variable delete"
      ];
      deniedCommands = builtins.toJSON (
        lib.unique (baseDeniedCommands ++ config.dotfiles.fence.deniedCommands)
      );

      isPermissive = lib.elem "*" config.dotfiles.fence.allowedDomains;
      fenceWrap =
        cmd:
        if isPermissive then
          "fence env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy ${cmd}"
        else
          "fence ${cmd}";
      wrappedAliases = lib.genAttrs config.dotfiles.fence.wrap fenceWrap;
    in
    {
      home.packages = [
        pkgs.llm-agents.fence
      ]
      ++ lib.optionals isLinux [
        pkgs.bubblewrap
        pkgs.bpftrace
      ];
      programs.zsh.shellAliases = wrappedAliases;
      programs.bash.shellAliases = wrappedAliases;
      xdg.configFile = {
        "fence/fence.json".text = ''
          {
            "$schema": "https://raw.githubusercontent.com/Use-Tusk/fence/main/docs/schema/fence.schema.json",
            "allowPty": true,
            "network": {
              "allowLocalBinding": true,
              "allowLocalOutbound": true,
              "allowedDomains": ${allowedDomains},
              "allowUnixSockets": ${allowedUnixSockets},
              "deniedDomains": [
                // Cloud metadata APIs (prevent credential theft)
                "169.254.169.254",
                "metadata.google.internal",
                "instance-data.ec2.internal",

                // Telemetry (optional, can be removed if needed)
                "statsig.anthropic.com",
                "*.sentry.io"
              ]
            },

            "filesystem": {
              "allowRead": [
                "/nix/**",
                "~/.config/**"
              ],
              "allowWrite": [
                ".",

                // Go
                "~/pkg/**",

                // Temp files
                "/tmp",

                // Local cache, needed by tools like `uv`
                "~/.cache/**",

                // OpenCode
                "~/.opencode/**",
                "~/.local/state/**",

                // Docker
                "~/.docker/buildx/**",

                // Package manager caches
                "~/.npm/_cacache",
                "~/.npm/_npx",
                "~/.cache",
                "~/.bun/**",

                // Cargo cache (Rust, used by Codex)
                "~/.cargo/registry/**",
                "~/.cargo/git/**",
                "~/.cargo/.package-cache",

                // Shell completion cache
                "~/.zcompdump*",

                // XDG directories for app configs/data
                "~/.local/share/**",
              ],

              "denyRead": [
                // WSL2
                "/mnt/c/**",

                // SSH private keys and config
                "~/.ssh/id_*",
                "~/.ssh/config",
                "~/.ssh/*.pem",

                // GPG keys
                "~/.gnupg/**",

                // Cloud provider credentials
                "~/.aws/**",
                "~/.config/gcloud/**",
                "~/.kube/**",

                // Package manager auth tokens
                "~/.pypirc",
                "~/.netrc",
                "~/.git-credentials",
                "~/.cargo/credentials",
                "~/.cargo/credentials.toml"
              ]
            },

            "command": {
              "useDefaults": true,
              "acceptSharedBinaryCannotRuntimeDeny": [
                "chroot"
              ],
              "deny": ${deniedCommands}
            }
          }
        '';
      };
    };
}
