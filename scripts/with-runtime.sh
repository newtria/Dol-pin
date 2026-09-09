#!/usr/bin/env bash
# Keep VM disks, downloads and temporary files on an explicitly selected volume.
# Example: DOLPIN_RUNTIME_ROOT=/Volumes/SSD/dol-pin-runtime bash scripts/with-runtime.sh start
set -euo pipefail

: "${DOLPIN_RUNTIME_ROOT:?Set DOLPIN_RUNTIME_ROOT to an existing external-volume directory}"
if [[ "$DOLPIN_RUNTIME_ROOT" != /* || ! -d "$DOLPIN_RUNTIME_ROOT" ]]; then
  echo 'DOLPIN_RUNTIME_ROOT must be an existing absolute directory.' >&2
  exit 1
fi

export COLIMA_HOME="$DOLPIN_RUNTIME_ROOT/colima"
export COLIMA_CACHE_HOME="$DOLPIN_RUNTIME_ROOT/cache/colima"
export LIMA_HOME="$COLIMA_HOME/_lima"
export TMPDIR="$DOLPIN_RUNTIME_ROOT/tmp"
export npm_config_cache="$DOLPIN_RUNTIME_ROOT/cache/npm"
export PATH="$DOLPIN_RUNTIME_ROOT/bin:$PATH"
mkdir -p "$COLIMA_HOME" "$COLIMA_CACHE_HOME" "$TMPDIR" "$npm_config_cache"

case "${1:-}" in
  start)
    exec colima start dol-pin --cpu 4 --memory 3 --disk 40 --root-disk 12 \
      --vm-type vz --runtime docker --activate=false --ssh-config=false
    ;;
  status)
    exec colima status dol-pin
    ;;
  '')
    echo 'Usage: with-runtime.sh start|status|COMMAND [ARGS...]' >&2
    exit 2
    ;;
  *)
    export DOCKER_HOST="unix://$COLIMA_HOME/dol-pin/docker.sock"
    exec "$@"
    ;;
esac
