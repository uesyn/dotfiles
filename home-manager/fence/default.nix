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
      default = [ ];
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
      description = "Denied commands for network access in fence.";
    };
  };

  config =
    let
      allowedDomains = builtins.toJSON config.dotfiles.fence.allowedDomains;
      allowedUnixSockets = builtins.toJSON config.dotfiles.fence.allowedUnixSockets;
      deniedCommands = builtins.toJSON config.dotfiles.fence.deniedCommands;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
    in
    {
      home.packages = [
        pkgs.llm-agents.fence
      ]
      ++ lib.optionals isLinux [
        pkgs.bubblewrap
        pkgs.bpftrace
      ];
      xdg.configFile = {
        "fence/fence.json".text = ''
          {
            "$schema": "https://raw.githubusercontent.com/Use-Tusk/fence/main/docs/schema/fence.schema.json",
            "extends": "./base.json",
            "command": {
              "deny": ${deniedCommands},
            },
            "network": {
              "allowedDomains": ${allowedDomains},
              "allowUnixSockets": ${allowedUnixSockets}
            },
          }
        '';
        "fence/base.json".text = ''
          {
            "allowPty": true,
            "network": {
              "allowLocalBinding": true,
              "allowLocalOutbound": true,
              "allowUnixSockets": [
                // Colima
                "~/.colima/docker.sock",
                "~/.colima/default/docker.sock",
                "~/.config/colima/docker.sock"
              ],
              "allowedDomains": [
                // MiniMax
                "*.minimax.io",
                "*.exa.ai",

                // Sakura Internet
                "*.sakura.ad.jp",

                // Go
                "*.pkg.go.dev",

                // LLM API providers
                "api.openai.com",
                "*.anthropic.com",
                "api.githubcopilot.com",
                "generativelanguage.googleapis.com",
                "api.mistral.ai",
                "api.cohere.ai",
                "api.together.xyz",
                "openrouter.ai",
                "api.morphllm.com",
                "*.amazonaws.com",

                // OpenCode
                "opencode.ai",
                "api.opencode.ai",

                // Amp
                "ampcode.com",
                "*.ampcode.com",

                // Factory CLI (droid)
                "*.factory.ai",
                "api.workos.com",

                // Cursor API
                "*.cursor.sh",

                // Charm
                "data.charm.land",
                "catwalk.charm.sh",

                // Copilot
                "*.githubcopilot.com",

                // Git hosting
                "github.com",
                "api.github.com",
                "raw.githubusercontent.com",
                "codeload.github.com",
                "objects.githubusercontent.com",
                "release-assets.githubusercontent.com",
                "gitlab.com",

                // Package registries
                "registry.npmjs.org",
                "*.npmjs.org",
                "registry.yarnpkg.com",
                "pypi.org",
                "files.pythonhosted.org",
                "crates.io",
                "static.crates.io",
                "index.crates.io",
                "proxy.golang.org",
                "sum.golang.org",
                "formulae.brew.sh",

                // Model registry
                "models.dev"
              ],

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

                // Docker config (may contain registry auth)
                "~/.docker/**",

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
              "deny": [
                // Git commands that modify remote state
                "git push",
                "git reset",
                "git clean",
                "git checkout --",
                "git rebase",
                "git merge",

                // Package publishing commands
                "npm publish",
                "pnpm publish",
                "yarn publish",
                "cargo publish",
                "twine upload",
                "gem push",

                // Privilege escalation
                "sudo",

                // GitHub CLI commands that modify remote state
                "gh pr create",
                "gh pr merge",
                "gh pr close",
                "gh pr reopen",
                "gh pr review",
                "gh pr comment",
                "gh release create",
                "gh release delete",
                "gh repo create",
                "gh repo fork",
                "gh repo delete",
                "gh issue create",
                "gh issue close",
                "gh issue comment",
                "gh gist create",
                "gh workflow run",
                "gh api",
                "gh auth login",
                "gh secret set",
                "gh secret delete",
                "gh variable set",
                "gh variable delete"
              ]
            }
          }
        '';
      };
    };
}
