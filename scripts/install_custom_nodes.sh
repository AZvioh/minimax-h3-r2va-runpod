#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/ComfyUI}"
CUSTOM_DIR="$COMFYUI_DIR/custom_nodes"
mkdir -p "$CUSTOM_DIR"

RGTHREE_REF="${RGTHREE_REF:-6b76ee6f2c5a007710b5a16f97c94330d6ecc871}"
VHS_REF="${VHS_REF:-4ee72c065db22c9d96c2427954dc69e7b908444b}"
RIFE_REF="${RIFE_REF:-51d88c0c0db49308dd3ade9edd4a5c1bcdf4ec72}"
UPSCALER_REF="${UPSCALER_REF:-6b8951d7413b41d9639be91888ef65b63827b930}"
REFPACK_REF="${REFPACK_REF:-main}"
INSTALL_OPTIONAL_RIFE="${INSTALL_OPTIONAL_RIFE:-true}"
INSTALL_OPTIONAL_UPSCALER="${INSTALL_OPTIONAL_UPSCALER:-true}"

install_repo() {
  local name="$1" url="$2" ref="$3" required="$4"
  local dir="$CUSTOM_DIR/$name"
  echo "[nodes] $name @ $ref"
  if [[ ! -d "$dir/.git" ]]; then
    rm -rf "$dir"
    git clone "$url" "$dir"
  fi
  (
    cd "$dir"
    git fetch --all --tags --prune || true
    if ! git checkout --detach "$ref" 2>/dev/null; then
      git checkout "$ref"
      git pull --ff-only || true
    fi
    if [[ -f requirements.txt ]]; then
      python -m pip install --prefer-binary -r requirements.txt
    fi
    if [[ -f install.py ]]; then
      python install.py || {
        [[ "$required" == "required" ]] && exit 1 || echo "[nodes] optional install.py failed: $name"
      }
    fi
  ) || {
    if [[ "$required" == "required" ]]; then
      echo "[nodes] FATAL: required node pack failed: $name" >&2
      exit 1
    fi
    echo "[nodes] WARNING: optional node pack failed: $name" >&2
  }
}

# REQUIRED for the modified workflow UI/reference system and modular LoRAs.
install_repo "ComfyUI-MiniMaxRefPack" "https://github.com/Hearmeman24/ComfyUI-MiniMaxRefPack.git" "$REFPACK_REF" required
install_repo "rgthree-comfy" "https://github.com/rgthree/rgthree-comfy.git" "$RGTHREE_REF" required

# REQUIRED only for the optional MP4 branches; native core SaveVideo is ComfyUI core.
install_repo "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$VHS_REF" optional

if [[ "$INSTALL_OPTIONAL_RIFE" == "true" ]]; then
  install_repo "ComfyUI-RIFE-TensorRT-Auto" "https://github.com/huchukato/ComfyUI-RIFE-TensorRT-Auto.git" "$RIFE_REF" optional
fi
if [[ "$INSTALL_OPTIONAL_UPSCALER" == "true" ]]; then
  install_repo "ComfyUI-Upscaler-TensorRT-Auto" "https://github.com/huchukato/ComfyUI-Upscaler-TensorRT-Auto.git" "$UPSCALER_REF" optional
fi

echo "[nodes] install complete"
