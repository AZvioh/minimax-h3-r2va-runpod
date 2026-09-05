#!/usr/bin/env bash
set -u

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"

WORKSPACE="/workspace"

QUEUE_INTERVAL="${QUEUE_BACKUP_INTERVAL:-5}"
INPUT_INTERVAL="${INPUT_BACKUP_INTERVAL:-60}"

QUEUE_FILE="${WORKSPACE}/queue_latest.json"
QUEUE_TMP="${WORKSPACE}/queue_latest.json.tmp"

INPUT_SOURCE="${COMFYUI_DIR}/input/"
INPUT_BACKUP="${WORKSPACE}/INPUT_BACKUP/"

log() {
  echo "[$(date '+%F %T')] [backup] $*"
}

mkdir -p "${INPUT_BACKUP}"

last_input_backup=0

log "Automatic state backup started."
log "Queue interval: ${QUEUE_INTERVAL}s"
log "Input interval: ${INPUT_INTERVAL}s"

while true; do

  # Queue backup.
  if curl -fsS \
    "http://127.0.0.1:${COMFYUI_PORT}/queue" \
    -o "${QUEUE_TMP}" 2>/dev/null; then

    mv -f "${QUEUE_TMP}" "${QUEUE_FILE}"
  fi

  now="$(date +%s)"

  # Input backup.
  if (( now - last_input_backup >= INPUT_INTERVAL )); then

    if [[ -d "${INPUT_SOURCE}" ]]; then
      rsync -a \
        "${INPUT_SOURCE}" \
        "${INPUT_BACKUP}" \
        >/dev/null 2>&1 || true
    fi

    last_input_backup="${now}"
  fi

  sleep "${QUEUE_INTERVAL}"
done
