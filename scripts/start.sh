#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_ROOT="/opt/h3-template"
WORKSPACE_ROOT="/workspace"
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
COMFY_SRC_FALLBACK="/ComfyUI"

LOG_FILE_MAIN="${WORKSPACE_ROOT}/comfyui.log"
LOG_FILE_USER="${COMFYUI_DIR}/user/comfyui_${COMFYUI_PORT}.log"
EXIT_FILE="${WORKSPACE_ROOT}/comfyui_exit.txt"

log() {
  echo "[h3-template] $*"
}

# Prevent duplicate ComfyUI launches
if pgrep -f "python .*main.py.*--port ${COMFYUI_PORT}" >/dev/null 2>&1 || \
   pgrep -f "python main.py.*--port ${COMFYUI_PORT}" >/dev/null 2>&1; then
  log "ComfyUI already running on port ${COMFYUI_PORT}. Exiting."
  exit 0
fi

# Copy the baked ComfyUI install into persistent /workspace on first boot
if [[ ! -f "${COMFYUI_DIR}/main.py" ]]; then
  log "ComfyUI not found at ${COMFYUI_DIR}. Copying base install..."

  mkdir -p "${COMFYUI_DIR}"

  if [[ -d "${COMFY_SRC_FALLBACK}" && -f "${COMFY_SRC_FALLBACK}/main.py" ]]; then
    rsync -a "${COMFY_SRC_FALLBACK}/" "${COMFYUI_DIR}/"
  else
    log "ERROR: Could not find baked ComfyUI install at ${COMFY_SRC_FALLBACK}"
    exit 1
  fi
fi

# Required persistent folders
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
  "${COMFYUI_DIR}/models/tensorrt"

# Sync bundled workflows
if [[ -d "${TEMPLATE_ROOT}/workflows" ]]; then
  log "Syncing bundled workflows..."
  rsync -a "${TEMPLATE_ROOT}/workflows/" "${COMFYUI_DIR}/user/default/workflows/"
fi

# Required H3 model setup
if [[ -x "${TEMPLATE_ROOT}/scripts/download_models.sh" ]]; then
  log "Checking required MiniMax H3 models..."
  bash "${TEMPLATE_ROOT}/scripts/download_models.sh"
else
  log "ERROR: Required download_models.sh is missing or not executable."
  exit 1
fi

# Optional CivitAI LoRAs
if [[ -x "${TEMPLATE_ROOT}/scripts/download_civitai_loras.sh" ]]; then
  log "Checking optional CivitAI LoRAs..."

  if ! bash "${TEMPLATE_ROOT}/scripts/download_civitai_loras.sh"; then
    log "WARNING: Optional CivitAI LoRA download failed. Continuing without those LoRAs."
  fi
fi

# Remove stale SQLite lock left by a dead ComfyUI process
rm -f "${COMFYUI_DIR}/user/comfyui.db.lock" || true

cd "${COMFYUI_DIR}"

# Dual logging
mkdir -p "$(dirname "${LOG_FILE_USER}")"
exec > >(tee -a "${LOG_FILE_MAIN}" "${LOG_FILE_USER}") 2>&1

log "Launching ComfyUI..."
log "Port: ${COMFYUI_PORT}"
log "ComfyUI dir: ${COMFYUI_DIR}"
log "Logs: ${LOG_FILE_MAIN} and ${LOG_FILE_USER}"

# Stable defaults discovered during testing:
# - no SageAttention
# - no --cuda-malloc
# - no --disable-dynamic-vram
# - --cache-none prevents intermediate-cache RAM accumulation
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

exit "${EXIT_CODE}"
