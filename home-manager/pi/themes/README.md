# Pi themes

Pi themes vendored into this repository, installed to `~/.pi/agent/themes/`
(read-only store symlinks) by `../default.nix` and selected with the `theme`
setting.

## dracula

Fork of [dracula/pi-coding-agent](https://github.com/dracula/pi-coding-agent)
(`dracula.json` kept byte-identical to upstream, commit
`4636a603d3c96395732a73ac84d1e7dee1368a55`), MIT licensed — see `LICENSE`.

Upstream `$schema` still points at the pi-mono source tree; the canonical
published schema is <https://pi.dev/schemas/theme.schema.json>.

Update:

```sh
curl -fsSL https://raw.githubusercontent.com/dracula/pi-coding-agent/main/dracula.json \
  -o dracula.json
```

The file name must match the theme `name`, and a user theme only hot-reloads
from `~/.pi/agent/themes/<name>.json`; run `/reload` after changing anything
else, or restart Pi.
