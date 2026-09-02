#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
IMAGE_COMFYUI="${IMAGE_COMFYUI:-/ComfyUI}"
COMFYUI_DIR="${COMFYUI_DIR:-${WORKSPACE_PATH}/ComfyUI}"
TEMPLATE_DIR="/opt/h3-template"

log() {
  echo "[storage] $*"
}

mkdir -p "${WORKSPACE_PATH}"

# First boot only:
# copy the baked ComfyUI installation into persistent /workspace.
if [[ ! -f "${COMFYUI_DIR}/main.py" ]]; then
  log "First boot: preparing persistent ComfyUI installation..."

  if [[ ! -f "${IMAGE_COMFYUI}/main.py" ]]; then
    log "ERROR: baked ComfyUI installation not found at ${IMAGE_COMFYUI}"
    exit 1
  fi

  mkdir -p "${COMFYUI_DIR}"

  # Do NOT use --delete against persistent user storage.
  rsync -a "${IMAGE_COMFYUI}/" "${COMFYUI_DIR}/"

  if [[ ! -f "${COMFYUI_DIR}/main.py" ]]; then
    log "ERROR: ComfyUI copy failed."
    exit 1
  fi

  log "Base ComfyUI copied successfully."
else
  log "Existing persistent ComfyUI installation found."
fi

# Persistent directories used by this template.
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
  "${COMFYUI_DIR}/models/tensorrt"

# Install the bundled default workflow if it exists.
DEFAULT_WORKFLOW="${TEMPLATE_DIR}/workflows/MiniMax_H3_R2VA_Custom_RunPod.json"

if [[ -f "${DEFAULT_WORKFLOW}" ]]; then
  install -m 0644 \
    "${DEFAULT_WORKFLOW}" \
    "${COMFYUI_DIR}/user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json"

  log "Default workflow installed."
else
  log "WARNING: bundled default workflow not found:"
  log "${DEFAULT_WORKFLOW}"
fi

log "Persistent ComfyUI: ${COMFYUI_DIR}"
log "Storage setup complete."
