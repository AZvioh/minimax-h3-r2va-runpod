#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/ComfyUI}"
CUSTOM_DIR="${COMFYUI_DIR}/custom_nodes"

mkdir -p "${CUSTOM_DIR}"

RGTHREE_REF="${RGTHREE_REF:-6b76ee6f2c5a007710b5a16f97c94330d6ecc871}"
VHS_REF="${VHS_REF:-4ee72c065db22c9d96c2427954dc69e7b908444b}"
RIFE_REF="${RIFE_REF:-51d88c0c0db49308dd3ade9edd4a5c1bcdf4ec72}"
UPSCALER_REF="${UPSCALER_REF:-6b8951d7413b41d9639be91888ef65b63827b930}"
REFPACK_REF="${REFPACK_REF:-main}"

INSTALL_OPTIONAL_RIFE="${INSTALL_OPTIONAL_RIFE:-true}"
INSTALL_OPTIONAL_UPSCALER="${INSTALL_OPTIONAL_UPSCALER:-true}"

log() {
  echo "[nodes] $*"
}

install_repo() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local required="$4"

  local dir="${CUSTOM_DIR}/${name}"

  log "Installing ${name} @ ${ref}"

  rm -rf "${dir}"

  if ! git clone --filter=blob:none "${url}" "${dir}"; then
    if [[ "${required}" == "required" ]]; then
      log "FATAL: failed to clone required node pack: ${name}"
      exit 1
    fi

    log "WARNING: failed to clone optional node pack: ${name}"
    return 0
  fi

  (
    cd "${dir}"

    git fetch --tags --force

    if git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
      git checkout --detach "${ref}"
    else
      log "Ref ${ref} was not already available locally; fetching directly..."
      git fetch origin "${ref}"

      if git rev-parse --verify FETCH_HEAD >/dev/null 2>&1; then
        git checkout --detach FETCH_HEAD
      else
        log "ERROR: could not resolve ${name} ref ${ref}"
        exit 1
      fi
    fi

    log "${name} resolved to $(git rev-parse HEAD)"

    if [[ -f requirements.txt ]]; then
      log "Installing ${name} requirements..."
      python -m pip install \
        --prefer-binary \
        --disable-pip-version-check \
        -r requirements.txt
    fi

    if [[ -f install.py ]]; then
      log "Running ${name}/install.py..."
      python install.py
    fi
  )

  status=$?

  if [[ ${status} -ne 0 ]]; then
    if [[ "${required}" == "required" ]]; then
      log "FATAL: required node pack failed: ${name}"
      exit "${status}"
    fi

    log "WARNING: optional node pack failed: ${name}"
    rm -rf "${dir}"
    return 0
  fi

  log "Installed ${name}"
}

# REQUIRED:
# MiniMax reference / prompt system used by the shipped workflow.
install_repo \
  "ComfyUI-MiniMaxRefPack" \
  "https://github.com/Hearmeman24/ComfyUI-MiniMaxRefPack.git" \
  "${REFPACK_REF}" \
  "required"

# REQUIRED:
# Utility nodes used by the workflow.
install_repo \
  "rgthree-comfy" \
  "https://github.com/rgthree/rgthree-comfy.git" \
  "${RGTHREE_REF}" \
  "required"

# OPTIONAL:
# MP4/video helper nodes.
install_repo \
  "ComfyUI-VideoHelperSuite" \
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" \
  "${VHS_REF}" \
  "optional"

# OPTIONAL:
# TensorRT RIFE interpolation.
if [[ "${INSTALL_OPTIONAL_RIFE}" == "true" ]]; then
  install_repo \
    "ComfyUI-RIFE-TensorRT-Auto" \
    "https://github.com/huchukato/ComfyUI-RIFE-TensorRT-Auto.git" \
    "${RIFE_REF}" \
    "optional"
fi

# OPTIONAL:
# TensorRT upscaling.
if [[ "${INSTALL_OPTIONAL_UPSCALER}" == "true" ]]; then
  install_repo \
    "ComfyUI-Upscaler-TensorRT-Auto" \
    "https://github.com/huchukato/ComfyUI-Upscaler-TensorRT-Auto.git" \
    "${UPSCALER_REF}" \
    "optional"
fi

log "Custom-node installation complete."
