#! /usr/bin/env bash

# based on https://raw.githubusercontent.com/tailscale/tailscale/v1.30.2/docs/k8s/run.sh

(
  TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
  TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-}"
  
  set -e
  
  if [[ -z "${TAILSCALE_AUTH_KEY}" ]]; then
    exec "$@"
  fi
  
  TAILSCALED_ARGS="--tun=userspace-networking --state=mem: --statedir=/tmp --socket=/tmp/tailscaled.sock"
  
  TAILSCALE_UP_ARGS="--ssh"
  if [[ ! -z "${TAILSCALE_AUTH_KEY}" ]]; then
    TAILSCALE_UP_ARGS="--authkey=${TAILSCALE_AUTH_KEY} ${TAILSCALE_UP_ARGS}"
  fi
  if [[ ! -z "${TAILSCALE_HOSTNAME}" ]]; then
    TAILSCALE_UP_ARGS="--hostname=${TAILSCALE_HOSTNAME} ${TAILSCALE_UP_ARGS}"
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    sudo tailscaled ${TAILSCALED_ARGS} &
    sudo tailscale --socket=/tmp/tailscaled.sock up ${TAILSCALE_UP_ARGS}
  else
    tailscaled ${TAILSCALED_ARGS} &
    tailscale --socket=/tmp/tailscaled.sock up ${TAILSCALE_UP_ARGS}
  fi
) &
exec "$@"
