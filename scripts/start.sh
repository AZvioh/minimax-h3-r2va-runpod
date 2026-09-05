#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_ROOT="/opt/h3-template"
WORKSPACE_ROOT="/workspace"
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
COMFY_SRC_FALLBACK="/ComfyUI"

LOG_FILE_MAIN="${WORKSPACE_ROOT}/comfyui.log"
LOG_FILE_USER="${COMFYUI_DIR}/user/comfyui_${COMFYUI_PORT}.log"
EXIT_FILE="${WORKSPACE_ROOT}/comfyui_exit.txt"
RESCUE_FLAG="${WORKSPACE_ROOT}/RESCUE_MODE"

log() {
  echo "[h3-template] $*"
}

# Prevent duplicate ComfyUI launches.
if pgrep -f "python .*main.py.*--port ${COMFYUI_PORT}" >/dev/null 2>&1; then
  log "ComfyUI already running on port ${COMFYUI_PORT}. Exiting."
  exit 0
fi

# First boot: copy baked ComfyUI into persistent workspace.
if [[ ! -f "${COMFYUI_DIR}/main.py" ]]; then
  log "ComfyUI not found at ${COMFYUI_DIR}. Copying baked install..."

  mkdir -p "${COMFYUI_DIR}"

  if [[ -f "${COMFY_SRC_FALLBACK}/main.py" ]]; then
    rsync -a "${COMFY_SRC_FALLBACK}/" "${COMFYUI_DIR}/"
  else
    log "ERROR: baked ComfyUI not found at ${COMFY_SRC_FALLBACK}"
    exit 1
  fi
fi

mkdir -p \
  "${COMFYUI_DIR}/input" \
  "${COMFYUI_DIR}/output" \
  "${COMFYUI_DIR}/temp" \
  "${COMFYUI_DIR}/user" \
  "${COMFYUI_DIR}/user/default/workflows" \
  "${COMFYUI_DIR}/models/checkpoints" \
  "${COMFYUI_DIR}/models/diffusion_models" \
  "${COMFYUI_DIR}/models/text_encoders" \
  "${COMFYUI_DIR}/models/vae" \
  "${COMFYUI_DIR}/models/loras" \
  "${COMFYUI_DIR}/models/upscale_models" \
  "${COMFYUI_DIR}/models/onnx" \
  "${COMFYUI_DIR}/models/tensorrt" \
  "${WORKSPACE_ROOT}/INPUT_BACKUP"

# Optional bundled workflows.
if [[ -d "${TEMPLATE_ROOT}/workflows" ]]; then
  rsync -a "${TEMPLATE_ROOT}/workflows/" \
    "${COMFYUI_DIR}/user/default/workflows/" || true
fi

# Required MiniMax H3 models.
if [[ -x "${TEMPLATE_ROOT}/scripts/download_models.sh" ]]; then
  log "Checking required MiniMax H3 models..."
  bash "${TEMPLATE_ROOT}/scripts/download_models.sh"
else
  log "ERROR: download_models.sh missing."
  exit 1
fi

# CivitAI is intentionally NOT downloaded automatically here.
# Optional LoRAs can be downloaded manually after startup.

# Start automatic queue + input backup service.
if [[ -x "${TEMPLATE_ROOT}/scripts/backup_state.sh" ]]; then
  log "Starting automatic queue/input backup service..."
  nohup "${TEMPLATE_ROOT}/scripts/backup_state.sh" \
    > "${WORKSPACE_ROOT}/backup_state.log" 2>&1 < /dev/null &
fi

# Start JupyterLab if it is not already running.
if ! pgrep -f "jupyter-lab.*--port=${JUPYTER_PORT}" >/dev/null 2>&1; then

  if [[ -z "${JUPYTER_TOKEN:-}" ]]; then
    if [[ -f "${WORKSPACE_ROOT}/jupyter_token.txt" ]]; then
      JUPYTER_TOKEN="$(cat "${WORKSPACE_ROOT}/jupyter_token.txt")"
    else
      JUPYTER_TOKEN="$(python -c 'import secrets; print(secrets.token_urlsafe(24))')"
      printf '%s\n' "${JUPYTER_TOKEN}" > "${WORKSPACE_ROOT}/jupyter_token.txt"
      chmod 600 "${WORKSPACE_ROOT}/jupyter_token.txt"
    fi
  fi

  log "Starting JupyterLab on port ${JUPYTER_PORT}..."

  nohup jupyter lab \
    --ip=0.0.0.0 \
    --port="${JUPYTER_PORT}" \
    --no-browser \
    --allow-root \
    --ServerApp.root_dir="${WORKSPACE_ROOT}" \
    --ServerApp.token="${JUPYTER_TOKEN}" \
    > "${WORKSPACE_ROOT}/jupyter.log" 2>&1 < /dev/null &
fi

# Rescue mode intentionally leaves the container alive without ComfyUI.
if [[ -f "${RESCUE_FLAG}" ]]; then
  log "RESCUE_MODE flag detected."
  log "ComfyUI will not start."
  log "JupyterLab and filesystem access remain available."
  exec sleep infinity
fi

rm -f "${COMFYUI_DIR}/user/comfyui.db.lock" || true

cd "${COMFYUI_DIR}"

mkdir -p "$(dirname "${LOG_FILE_USER}")"

exec > >(tee -a "${LOG_FILE_MAIN}" "${LOG_FILE_USER}") 2>&1

log "Launching ComfyUI..."
log "Port: ${COMFYUI_PORT}"
log "ComfyUI dir: ${COMFYUI_DIR}"

DEFAULT_ARGS="--disable-auto-launch --async-offload --cache-none"
COMFYUI_EXTRA_ARGS="${COMFYUI_EXTRA_ARGS:-$DEFAULT_ARGS}"

log "Args: ${COMFYUI_EXTRA_ARGS}"

read -r -a EXTRA_ARGS_ARR <<< "${COMFYUI_EXTRA_ARGS}"

rm -f "${EXIT_FILE}" || true

export PYTHONUNBUFFERED=1

set +e

python -X faulthandler main.py \
  --listen 0.0.0.0 \
  --port "${COMFYUI_PORT}" \
  "${EXTRA_ARGS_ARR[@]}"

EXIT_CODE=$?

set -e

echo "[$(date '+%F %T')] ComfyUI exited with code ${EXIT_CODE}" \
  | tee -a "${EXIT_FILE}" "${LOG_FILE_MAIN}" "${LOG_FILE_USER}"

# If rescue was requested while ComfyUI was running,
# keep the container alive instead of exiting.
if [[ -f "${RESCUE_FLAG}" ]]; then
  log "Entering rescue mode."
  exec sleep infinity
fi

exit "${EXIT_CODE}"
