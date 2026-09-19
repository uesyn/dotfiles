{ ... }:
let
  # argv matchers for `command_policies` invocation rules.
  argvPrefix = prefix: { argv.prefix = prefix; };

  # Allowed `gh` subcommands (read-only). Everything else is denied, so an
  # unknown or mutating command fails closed and help of denied commands is
  # not shown. Matching is `argv.prefix`: the subcommand path must come
  # first, so flags go after it (`gh repo list -R owner/repo`); leading
  # flags (`gh -R owner/repo repo list`) are denied. `contains` is not used
  # because another command's arguments could satisfy it
  # (`gh api -f repo list`).
  ghAllowRules = [
    [ "status" ]
    [ "--version" ]
    [ "--help" ]
    [ "-h" ]

    [
      "auth"
      "status"
    ]

    [
      "pr"
      "list"
    ]
    [
      "pr"
      "view"
    ]
    [
      "pr"
      "status"
    ]
    [
      "pr"
      "checks"
    ]
    [
      "pr"
      "diff"
    ]

    [
      "issue"
      "list"
    ]
    [
      "issue"
      "status"
    ]
    [
      "issue"
      "view"
    ]

    [
      "release"
      "list"
    ]
    [
      "release"
      "view"
    ]
    [
      "release"
      "download"
    ]
    [
      "release"
      "verify"
    ]
    [
      "release"
      "verify-asset"
    ]

    [
      "repo"
      "list"
    ]
    [
      "repo"
      "view"
    ]
    [
      "repo"
      "gitignore"
    ]
    [
      "repo"
      "license"
    ]
    [
      "repo"
      "read-dir"
    ]
    [
      "repo"
      "read-file"
    ]
    [
      "repo"
      "autolink"
      "list"
    ]
    [
      "repo"
      "autolink"
      "view"
    ]
    [
      "repo"
      "deploy-key"
      "list"
    ]

    [
      "workflow"
      "list"
    ]
    [
      "workflow"
      "view"
    ]

    [
      "run"
      "list"
    ]
    [
      "run"
      "view"
    ]
    [
      "run"
      "watch"
    ]
    [
      "run"
      "download"
    ]

    [
      "cache"
      "list"
    ]

    [
      "gist"
      "list"
    ]
    [
      "gist"
      "view"
    ]

    [
      "discussion"
      "list"
    ]
    [
      "discussion"
      "view"
    ]

    [
      "project"
      "list"
    ]
    [
      "project"
      "view"
    ]
    [
      "project"
      "field-list"
    ]
    [
      "project"
      "item-list"
    ]

    [
      "label"
      "list"
    ]

    [
      "secret"
      "list"
    ]
    [
      "variable"
      "list"
    ]
    [
      "variable"
      "get"
    ]

    [
      "search"
      "code"
    ]
    [
      "search"
      "commits"
    ]
    [
      "search"
      "issues"
    ]
    [
      "search"
      "prs"
    ]
    [
      "search"
      "repos"
    ]

    [
      "org"
      "list"
    ]

    [
      "ruleset"
      "check"
    ]
    [
      "ruleset"
      "list"
    ]
    [
      "ruleset"
      "view"
    ]

    [
      "attestation"
      "verify"
    ]
    [
      "attestation"
      "download"
    ]
    [
      "attestation"
      "trusted-root"
    ]
  ];

  # Tool-sandbox children start network-blocked and only get egress via an
  # explicit `network` grant; only `gh` opts in (`allow_all`), so both git
  # sandboxes stay fully offline (push/fetch cannot reach a network remote
  # even if argv allowed it).
  ghSandbox = {
    fs_read = [
      "."
      "/nix/store"
      "~/.config/gh"
      "~/.config/git"
    ];
    # CA bundles (Linux / macOS); missing paths are skipped.
    fs_read_file = [
      "/etc/ssl/certs/ca-certificates.crt"
      "/etc/ssl/cert.pem"
    ];
    fs_write = [ "." ];
    network.allow_all = true;
  };
  ghInvocationPolicy = {
    default = "deny";
    allow = map argvPrefix ghAllowRules;
  };
in
{
  dotfiles.nono.commandPolicies.commands.gh = pkgs: {
    executable = "${pkgs.gh}/bin/.gh-wrapped";
    can_use = [ "git" ];
    from.session = {
      sandbox = ghSandbox;
      invocation_policy = ghInvocationPolicy;
    };
  };
}
