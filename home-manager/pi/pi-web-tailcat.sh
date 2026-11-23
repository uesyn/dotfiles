#!/usr/bin/env bash
# One entry point for exposing the local pi-web server over a tailcat tunnel:
# `start` runs pi-web (unless it is already up) plus `tailcat serve`, `stop`
# takes the tunnel down again.
#
# Why the magic hostname: tailcat's SOCKS5 proxy dials the tailcat server named
# by its address argument when the browser asks for "server.tailcat". A browser
# cannot use a bare tailcat address as a hostname (addresses are case-sensitive,
# browser hostnames are lowercased), so this name is the only way in. pi-web's
# proxy answers only to loopback names, IPs and the hostnames in
# PI_WEB_ALLOWED_HOSTS (DNS-rebinding guard), so "server.tailcat" has to be
# added there.
#
# No TLS involved: tailcat is a WireGuard tunnel, so the password crosses the
# network encrypted while the browser still sees plain http (no secure context,
# HTTP/1.1 only).
#
# Transient systemd user services run pi-web and tailcat in the foreground.
# systemd owns process monitoring, termination and dependency propagation.
# No PID tracking, user/PID namespaces or persistent unit files are needed.
# `stop` stops the units; --collect unloads them after exit.

set -euo pipefail

readonly magic_host="server.tailcat"

subcmd="start"
port="30141"
allow=""
key="default"

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
  pi-web-tailcat [start] [options]   start pi-web if needed, then tunnel it
  pi-web-tailcat stop [-p PORT]      stop the tunnel and its pi-web

Options:
  -p, --port PORT           pi-web and tailcat port (default: 30141)
      --allow KEYS          comma-separated client node keys for tailcat serve
                            --allow, e.g. nodekey:... from "tailcat genkey
                            --client --key=client-default" on the client
      --key NAME            saved tailcat server key to serve with (default:
                            default); "new" for a throwaway key and address
  -h, --help                show this help

start keeps the address stable: it runs "tailcat genkey --key=NAME
--fixed-region" on first use instead of letting tailcat pick an ephemeral key
per run. The address is the key's, so two tunnels must not listen with the same
key at the same time (the connections land on whichever node answers); give the
second one --key NAME.

start reuses a pi-web that is already listening on PORT, and stop leaves that
one alone -- only what this command started lives inside its service cgroups.
The services are transient (no unit files), require systemd --user, and follow
that user's logout/linger policy. If the user manager is absent, start enables
linger with sudo loginctl enable-linger for the current user (sudo may prompt).

If pi-web runs unauthenticated, the address is the only credential, so start
warns and suggests --allow=nodekey:... (a client's key
from "tailcat genkey --client --key=client-default").

State lives in \$XDG_CACHE_HOME/tailcat/pi-web-PORT.{addr,log}.
Transient units: pi-web-tailcat-PORT.service and pi-web-tailcat-PORT-web.service.

Client side of the tunnel:
  tailcat socks --listen=127.0.0.1:1080 <addr>
  then open http://${magic_host}:<port>/ with the browser's SOCKS5 proxy set to
  127.0.0.1:1080 and remote DNS enabled (Firefox: "Proxy DNS when using SOCKS
  v5").
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
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1 (see --help)"
      ;;
    start | stop)
      subcmd="$1"
      shift
      ;;
    *)
      die "unexpected argument: $1 (see --help)"
      ;;
  esac
done

# Ports also become unit names and filenames; reject unsafe or ambiguous input.
if ! [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] || ((port > 65535)); then
  die "port must be an integer from 1 to 65535 (no leading zeros)"
fi

readonly unit="pi-web-tailcat-${port}.service"
readonly web_unit="pi-web-tailcat-${port}-web.service"
readonly state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tailcat"
readonly addr_file="${state_dir}/pi-web-${port}.addr"
readonly log_file="${state_dir}/pi-web-${port}.log"

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

connect_user_manager() {
  # tmux/SSH sessions can outlive or miss PAM's environment. Recover only an
  # existing runtime directory owned by this user; never create one ourselves.
  local runtime="/run/user/$UID"
  if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "$runtime" ] && [ -O "$runtime" ]; then
    export XDG_RUNTIME_DIR="$runtime"
  fi
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ] &&
    [ -S "$XDG_RUNTIME_DIR/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
  fi
  systemctl --user show-environment >/dev/null 2>&1
}

require_user_manager() {
  if connect_user_manager; then
    return 0
  fi

  local runtime="/run/user/$UID" user linger
  # Bootstrap only on start, and only when no local user manager is present.
  # A connection failure to an existing manager must not change login policy.
  if [ "${1:-}" = "enable-linger" ] &&
    [ ! -S "$runtime/systemd/private" ] && [ ! -S "$runtime/bus" ]; then
    user=$(id -un)
    linger=$(loginctl show-user "$user" --property=Linger --value 2>/dev/null) || linger=""
    if [ "$linger" != "yes" ]; then
      command -v sudo >/dev/null || die "sudo is required to enable linger for $user"
      note "enabling linger for $user; user services will be allowed to run after logout"
      note "running sudo loginctl enable-linger $user (sudo may request authentication)"
      sudo loginctl enable-linger "$user" || die "could not enable linger for $user"
    fi
    # logind may still be starting the runtime directory, manager and bus.
    for _ in $(seq 1 50); do
      if connect_user_manager; then
        return 0
      fi
      sleep 0.1
    done
  fi
  systemctl --user show-environment >/dev/null ||
    die "cannot reach systemd --user; run outside nono and check the user manager and connection environment"
}

lock_state() {
  mkdir -p "$state_dir"
  # Serialize start/stop for this port, including readiness and cleanup.
  exec {lock_fd}>"${state_dir}/pi-web-${port}.lock"
  flock "$lock_fd"
}

unit_running() {
  local state
  state=$(systemctl --user show --property=ActiveState --value "$1" 2>/dev/null) || return 1
  case "$state" in
    active | activating | reloading | deactivating) return 0 ;;
    *) return 1 ;;
  esac
}

# env_args is collected by cmd_start and shared with its start_unit calls.
start_unit() {
  local service="$1"
  shift
  systemd-run --user --collect \
    --unit="$service" --service-type=exec --expand-environment=no \
    --property=KillMode=control-group --property=TimeoutStopSec=10s \
    --property=Restart=no --working-directory="$PWD" \
    --property="StandardOutput=append:${log_file}" \
    --property=StandardError=inherit \
    "${env_args[@]}" "$@"
}

stop_unit() {
  local service
  for service in "$unit" "$web_unit"; do
    if unit_running "$service"; then
      systemctl --user stop "$service" || die "could not stop $service"
    fi
  done
  rm -f -- "$addr_file" "$addr_file.part"
  note "stopped"
  if pi_web_up; then
    note "a pi-web not started by this command is still listening on $(pi_web_url)"
  fi
}

fail_start() {
  note "$* (log: ${log_file})"
  tail -n 20 -- "$log_file" >&2 || true
  note "inspect with: journalctl --user -u $unit -u $web_unit"
  stop_unit
  exit 1
}

cmd_start() {
  lock_state
  require_user_manager enable-linger
  if unit_running "$unit"; then
    note "already running or stopping ($unit)"
    [ -s "$addr_file" ] && cat "$addr_file"
    return 0
  fi

  # Pass exported environment by name; values never enter systemd-run's argv.
  # env -0 works in Nix's non-interactive Bash and preserves multiline values.
  local entry name env_args=()
  while IFS= read -r -d '' entry; do
    name="${entry%%=*}"
    [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
    env_args+=("--setenv=$name")
  done < <(env -0)

  if [ "$key" != "new" ]; then
    local keys
    keys=$(tailcat genkey --list 2>/dev/null) || keys=""
    if ! printf '%s\n' "$keys" | grep -qx "$key"; then
      note "creating the saved server key ${key} for a stable address"
      tailcat genkey --key="$key" --fixed-region >/dev/null
    fi
  fi

  rm -f -- "$addr_file" "$addr_file.part"
  local owned_web=0 hosts web_command
  if unit_running "$web_unit"; then
    # Adopt our own web unit left by an interrupted start, not an external web.
    owned_web=1
  elif pi_web_up; then
    note "using the pi-web already listening on $(pi_web_url)"
  else
    web_command=$(command -v pi-web) || die "pi-web not found on PATH (mise install)"
    hosts="${PI_WEB_ALLOWED_HOSTS:-}"
    case ",${hosts}," in
      *",${magic_host},"*) ;;
      *) hosts="${hosts:+${hosts},}${magic_host}" ;;
    esac
    note "starting $web_unit (log: ${log_file})"
    PI_WEB_ALLOWED_HOSTS="$hosts" start_unit "$web_unit" \
      --setenv=PI_WEB_ALLOWED_HOSTS --setenv=PI_WEB_NO_OPEN=1 \
      -- "$web_command" --no-open --port "$port" ||
      fail_start "could not start $web_unit"
    owned_web=1
  fi

  if [ "$owned_web" = 1 ]; then
    # HTTP readiness is not implied by Type=exec; liveness belongs to systemd.
    for _ in $(seq 1 160); do
      pi_web_up && break
      unit_running "$web_unit" || fail_start "$web_unit exited before becoming ready"
      sleep 0.25
    done
    pi_web_up || fail_start "pi-web did not answer on $(pi_web_url)"
  fi
  if ! host_allowed; then
    if [ "$owned_web" = 1 ]; then
      fail_start "pi-web rejects Host: ${magic_host}"
    fi
    die "the running pi-web rejects Host: ${magic_host}; restart it with PI_WEB_ALLOWED_HOSTS=${magic_host}"
  fi

  if [ -z "$allow" ] && ! auth_has_password; then
    note "warning: pi-web has no password and no --allow was given, so the tunnel address alone grants access"
  fi

  local dependencies=() tailcat_args=(serve --key "$key")
  if [ "$owned_web" = 1 ]; then
    # Web failure stops the tunnel. Tunnel exit (including failure) stops only
    # our web unit. --no-block avoids waiting on ordered stop jobs here.
    dependencies+=(
      "--property=BindsTo=$web_unit"
      "--property=After=$web_unit"
      "--property=ExecStopPost=-$(command -v systemctl) --user --no-block stop $web_unit"
    )
  fi
  if [ -n "$allow" ]; then
    tailcat_args+=(--allow "$allow")
  fi
  tailcat_args+=("$port")
  if [ "$key" = "new" ]; then
    note "ephemeral key: the address changes on every start"
  fi

  note "starting $unit (log: ${log_file})"
  TAILCAT_ADDR_FILE="$addr_file.part" start_unit "$unit" \
    "${dependencies[@]}" --setenv=TAILCAT_ADDR_FILE \
    -- "$(command -v tailcat)" "${tailcat_args[@]}" ||
    fail_start "could not start $unit"

  # Relay registration can take up to two minutes. No PID tracking is needed.
  for _ in $(seq 1 240); do
    if [ -s "$addr_file.part" ] && grep -q '^tc' "$addr_file.part"; then
      break
    fi
    unit_running "$unit" || fail_start "$unit exited before publishing an address"
    sleep 0.5
  done
  if [ ! -s "$addr_file.part" ] || ! grep -q '^tc' "$addr_file.part"; then
    fail_start "tailcat did not publish an address"
  fi
  local addr
  addr=$(tr -d '\r\n' <"$addr_file.part")
  mv -- "$addr_file.part" "$addr_file"

  cat <<EOF

pi-web   $(pi_web_url)  (served as http://${magic_host}:${port}/)
tailcat  ${addr}
log      ${log_file}

stop:
  pi-web-tailcat stop -p ${port}
EOF
}

cmd_stop() {
  lock_state
  require_user_manager
  stop_unit
}

case "$subcmd" in
  start) cmd_start ;;
  stop) cmd_stop ;;
esac
