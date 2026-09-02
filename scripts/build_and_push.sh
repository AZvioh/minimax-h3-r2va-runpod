#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_IMAGE="mattdvs/minimax-h3-r2va-oneclick:v2"
IMAGE="${1:-$DEFAULT_IMAGE}"

log() {
  echo "[build] $*"
}

if ! command -v docker >/dev/null 2>&1; then
  echo "[build] ERROR: docker command not found." >&2
  exit 1
fi

log "Building image:"
log "${IMAGE}"

docker build \
  --pull \
  -t "${IMAGE}" \
  .

log "Build complete."
log "Pushing ${IMAGE} ..."

docker push "${IMAGE}"

log "Pushed successfully:"
log "${IMAGE}"
