#!/usr/bin/env bash
# One command for exposing the local pi-web server over a tailcat tunnel, and
# for dialing it from the client side with tailcat's SOCKS5 proxy.
#
# Why the magic hostname: tailcat's SOCKS5 proxy dials the tailcat server named
# by its address argument when the browser asks for "server.tailcat". A browser
# cannot use a bare tailcat address as a hostname (addresses are case-sensitive,
# browser hostnames are lowercased), so this name is the only way in. pi-web's
# proxy answers only to loopback names, IPs and the hostnames in
# PI_WEB_ALLOWED_HOSTS (DNS-rebinding guard), so "server.tailcat" has to be
# added there: `serve` does it when it starts pi-web and refuses to start the
# tunnel when an already running pi-web would reject the requests.
#
# No TLS involved: tailcat is a WireGuard tunnel, so the password crosses the
# network encrypted while the browser still sees plain http (no secure context,
# HTTP/1.1 only).

set -euo pipefail

readonly magic_host="server.tailcat"

subcmd="serve"
port="30141"
allow=""
key="default"
password_file=""
keep_pi_web=0
listen="127.0.0.1:1080"
resolved_password=""
positionals=()

die() {
  printf 'pi-web-tailcat: %s\n' "$*" >&2
  exit 1
}

note() {
  printf 'pi-web-tailcat: %s\n' "$*" >&2
}

usage() {
  cat <<EOF
Usage:
  pi-web-tailcat [serve] [options]   start pi-web if needed, then tunnel its port
  pi-web-tailcat connect [<addr>]    run the SOCKS5 proxy that dials the server
  pi-web-tailcat address             print the address the last serve published

Options:
  -p, --port PORT           pi-web and tailcat port (default: 30141)
      --allow KEYS          comma-separated client node keys for tailcat serve
                            --allow, e.g. nodekey:... from "tailcat genkey
                            --client --key=client-default" on the client
      --key NAME            saved tailcat server key to serve with (default:
                            default); "new" for a throwaway key and address
      --password-file FILE  read the pi-web password from FILE instead of
                            \$PI_WEB_PASSWORD; no password at all (the
                            default) leaves pi-web without authentication
      --keep-pi-web         leave a pi-web started by this command running
  -l, --listen ADDR:PORT    SOCKS5 listen address for connect
                            (default: 127.0.0.1:1080)
  -h, --help                show this help

serve prints the tailcat address and saves it to
\$XDG_CACHE_HOME/tailcat/pi-web-<port>.addr, which connect and address read
when no address is given. The address is stable only with a saved server key:
serve runs "tailcat genkey --key=default --fixed-region" for you on first use
instead of letting tailcat pick an ephemeral key per run. The address is the
key's, so two tunnels must not listen with the same key at the same time (the
connections land on whichever node answers); give the second one --key NAME.

Without a password pi-web runs unauthenticated and the address is the only
credential, so serve warns and suggests --allow=nodekey:... (a client's key
from "tailcat genkey --client --key=client-default").

Client side of the tunnel:
  tailcat socks --listen=127.0.0.1:1080 <addr>
  then open http://${magic_host}:<port>/ with the browser's SOCKS5 proxy set to
  127.0.0.1:1080 and remote DNS enabled (Firefox: "Proxy DNS when using SOCKS
  v5"). "pi-web-tailcat connect" does the first step.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --*=*)
      # Accept tailcat's own --flag=value form as well as --flag value.
      set -- "${1%%=*}" "${1#*=}" "${@:2}"
      continue
      ;;

    -p | --port)
      port="${2:?--port needs a value}"
      shift 2
      ;;
    --allow)
      allow="${2:?--allow needs a value}"
      shift 2
      ;;
    --key)
      key="${2:?--key needs a value}"
      shift 2
      ;;
    --password-file)
      password_file="${2:?--password-file needs a value}"
      shift 2
      ;;
    --keep-pi-web)
      keep_pi_web=1
      shift
      ;;
    -l | --listen)
      listen="${2:?--listen needs a value}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1 (see --help)"
      ;;
    serve | connect | address)
      subcmd="$1"
      shift
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if [ "${#positionals[@]}" -gt 0 ]; then
  set -- "${positionals[@]}"
else
  set --
fi
readonly cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/tailcat/pi-web-${port}.addr"

pi_web_url() {
  printf 'http://127.0.0.1:%s' "$port"
}

# pi-web answers "/" with 200 (no password) or a 307 to /login (password set),
# so curl's -f only fails while the server is not up yet.
pi_web_up() {
  curl -fsS -o /dev/null --max-time 2 "$(pi_web_url)/" 2>/dev/null
}

# The same probe with the hostname a SOCKS client will send; pi-web's proxy
# answers 403 "Untrusted request" when that name is not in its allow-list.
host_allowed() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
    -H "Host: ${magic_host}:${port}" "$(pi_web_url)/") || return 1
  [ "$code" != "403" ]
}

# Whether a password is set at all; pi-web reports it without needing one.
auth_has_password() {
  ! curl -s --max-time 3 "$(pi_web_url)/api/web-auth" 2>/dev/null | grep -q '"enabled":false'
}

# The password is optional: empty means pi-web runs without authentication
# (its own opt-in), and the warning in cmd_serve reports that. Sets
# resolved_password instead of printing it, so "die" cannot run in a command
# substitution subshell (whose exit trap would lose cmd_serve's locals).
resolve_password() {
  resolved_password=""
  if [ -n "$password_file" ]; then
    [ -r "$password_file" ] || die "cannot read $password_file"
    resolved_password=$(<"$password_file")
  else
    resolved_password="${PI_WEB_PASSWORD:-}"
  fi
}

cmd_serve() {
  local pi_pid="" started_pi=0 tc_pid="" addr_file="" log=""
  cleanup() {
    trap - EXIT INT TERM
    if [ -n "${tc_pid:-}" ]; then
      kill "$tc_pid" 2>/dev/null || true
    fi
    if [ "${started_pi:-0}" = 1 ] && [ "${keep_pi_web:-0}" = 0 ] && [ -n "${pi_pid:-}" ]; then
      kill "$pi_pid" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT INT TERM

  if pi_web_up; then
    note "pi-web already listening on $(pi_web_url)"
    if ! host_allowed; then
      die "the running pi-web rejects Host: ${magic_host}; restart it with PI_WEB_ALLOWED_HOSTS=${magic_host}"
    fi
  else
    command -v pi-web >/dev/null || die "pi-web not found on PATH (mise install)"
    resolve_password
    log=$(mktemp -t pi-web.XXXXXX.log)
    note "starting pi-web on $(pi_web_url) (log: $log)"
    PI_WEB_PASSWORD="$resolved_password" \
      PI_WEB_ALLOWED_HOSTS="${PI_WEB_ALLOWED_HOSTS:+${PI_WEB_ALLOWED_HOSTS},}${magic_host}" \
      PI_WEB_NO_OPEN=1 \
      pi-web --no-open --port "$port" >>"$log" 2>&1 &
    pi_pid=$!
    started_pi=1
    for _ in $(seq 1 160); do
      pi_web_up && break
      kill -0 "$pi_pid" 2>/dev/null || die "pi-web exited (see $log)"
      sleep 0.25
    done
    pi_web_up || die "pi-web did not answer on $(pi_web_url) (see $log)"
    host_allowed || die "pi-web rejects Host: ${magic_host} (see $log)"
  fi

  # The tunnel address is a credential: with no pi-web password, --allow is the
  # only thing between the internet and an agent that runs commands.
  if [ -z "$allow" ] && ! auth_has_password; then
    note "warning: pi-web has no password and no --allow was given, so the tunnel address alone grants access"
  fi

  if [ "$key" != "new" ]; then
    local keys
    keys=$(tailcat genkey --list 2>/dev/null) || keys=""
    if ! printf '%s\n' "$keys" | grep -qx "$key"; then
      note "creating the saved server key ${key} for a stable address"
      tailcat genkey --key="$key" --fixed-region >/dev/null
    fi
  fi

  mkdir -p "${cache_file%/*}"
  addr_file=$(mktemp -t pi-web-tailcat.XXXXXX)
  rm -f "$addr_file"

  local tailcat_args=(serve --key "$key")
  if [ -n "$allow" ]; then
    tailcat_args+=(--allow "$allow")
  fi
  tailcat_args+=("$port")
  if [ "$key" = "new" ]; then
    note "ephemeral key: the address below changes on every start"
  fi

  note "starting the tunnel on port ${port}"
  TAILCAT_ADDR_FILE="$addr_file" tailcat "${tailcat_args[@]}" &
  tc_pid=$!

  # Registering with a DERP relay can take a while (public relays rate-limit),
  # so give the tunnel more room than pi-web's local startup.
  for _ in $(seq 1 240); do
    if [ -s "$addr_file" ] && grep -q '^tc' "$addr_file"; then
      break
    fi
    kill -0 "$tc_pid" 2>/dev/null || die "tailcat serve exited"
    sleep 0.5
  done
  [ -s "$addr_file" ] || die "tailcat did not publish an address"

  local addr
  addr=$(tr -d '\r\n' <"$addr_file")
  [ -n "$addr" ] || die "tailcat published an empty address"
  printf '%s\n' "$addr" >"$cache_file"

  cat <<EOF

pi-web   $(pi_web_url)  (served as http://${magic_host}:${port}/)
tailcat  ${addr}
saved    ${cache_file}

client:
  tailcat socks --listen=127.0.0.1:1080 ${addr}
  browser -> http://${magic_host}:${port}/  with SOCKS5 127.0.0.1:1080
             and remote DNS enabled
  or run "pi-web-tailcat connect" on the client once the address is known

Ctrl-C stops the tunnel.
EOF

  wait "$tc_pid"
}

cmd_connect() {
  local addr="${1:-}"
  if [ -z "$addr" ]; then
    [ -r "$cache_file" ] || die "no address given and no ${cache_file}; run serve on the server or pass an address"
    addr=$(tr -d '\r\n' <"$cache_file")
  fi
  [ -n "$addr" ] || die "empty tailcat address"
  printf 'SOCKS5 %s -> %s\n' "$listen" "$addr"
  printf 'open http://%s:%s/ with remote DNS enabled\n' "$magic_host" "$port"
  exec tailcat socks --listen="$listen" "$addr"
}

cmd_address() {
  [ -r "$cache_file" ] || die "no ${cache_file}; run serve on the server first"
  tr -d '\r\n' <"$cache_file"
  printf '\n'
}

case "$subcmd" in
  serve)
    [ "$#" -eq 0 ] || die "unexpected argument: $1"
    cmd_serve
    ;;
  connect)
    cmd_connect "${1:-}"
    ;;
  address)
    cmd_address
    ;;
esac
