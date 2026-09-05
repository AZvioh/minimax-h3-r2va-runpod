#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/ComfyUI}"
CUSTOM_DIR="${COMFYUI_DIR}/custom_nodes"

RGTHREE_REF="${RGTHREE_REF:-main}"
VHS_REF="${VHS_REF:-main}"
RIFE_REF="${RIFE_REF:-main}"
UPSCALER_REF="${UPSCALER_REF:-main}"
REFPACK_REF="${REFPACK_REF:-main}"

mkdir -p "${CUSTOM_DIR}"

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

  if ! git clone "${url}" "${dir}"; then
    if [[ "${required}" == "true" ]]; then
      log "ERROR: failed to clone required node ${name}"
      exit 1
    else
      log "WARNING: failed to clone optional node ${name}"
      return 0
    fi
  fi

  if ! (
    cd "${dir}"

    git fetch --all --tags --force

    if git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
      git checkout --detach "${ref}"
    elif git rev-parse --verify "origin/${ref}^{commit}" >/dev/null 2>&1; then
      git checkout --detach "origin/${ref}"
    else
      echo "[nodes] ERROR: ref '${ref}' not found for ${name}" >&2
      exit 1
    fi

    log "${name} resolved to $(git rev-parse HEAD)"

    if [[ -f requirements.txt ]]; then
      log "Installing ${name} requirements..."
      python -m pip install --prefer-binary -r requirements.txt
    fi

    if [[ -f install.py ]]; then
      log "Running ${name} install.py..."
      python install.py
    fi
  ); then
    if [[ "${required}" == "true" ]]; then
      log "ERROR: failed installing required node ${name}"
      exit 1
    else
      log "WARNING: optional node ${name} failed to install"
      rm -rf "${dir}"
      return 0
    fi
  fi

  log "Installed ${name}"
}

install_repo \
  "ComfyUI-MiniMaxRefPack" \
  "https://github.com/numz/ComfyUI-MiniMaxRefPack.git" \
  "${REFPACK_REF}" \
  "true"

install_repo \
  "rgthree-comfy" \
  "https://github.com/rgthree/rgthree-comfy.git" \
  "${RGTHREE_REF}" \
  "true"

install_repo \
  "ComfyUI-VideoHelperSuite" \
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" \
  "${VHS_REF}" \
  "true"

install_repo \
  "ComfyUI-RIFE-TensorRT-Auto" \
  "https://github.com/huchukato/ComfyUI-RIFE-TensorRT-Auto.git" \
  "${RIFE_REF}" \
  "true"

install_repo \
  "ComfyUI-Upscaler-TensorRT-Auto" \
  "https://github.com/huchukato/ComfyUI-Upscaler-TensorRT-Auto.git" \
  "${UPSCALER_REF}" \
  "true"

log "Custom node installation complete."
