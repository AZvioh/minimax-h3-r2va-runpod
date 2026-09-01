#!/usr/bin/env bash
set -Eeuo pipefail

export WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
export COMFYUI_DIR="${COMFYUI_DIR:-$WORKSPACE_PATH/ComfyUI}"
export COMFYUI_PORT="${COMFYUI_PORT:-8188}"
export DOWNLOAD_H3_MODELS="${DOWNLOAD_H3_MODELS:-true}"
export DOWNLOAD_TURBO_LORA="${DOWNLOAD_TURBO_LORA:-true}"
export DEFAULT_H3_QUANT="${DEFAULT_H3_QUANT:-int8}"
export INSTALL_OPTIONAL_RIFE="${INSTALL_OPTIONAL_RIFE:-true}"
export INSTALL_OPTIONAL_UPSCALER="${INSTALL_OPTIONAL_UPSCALER:-true}"
export MODEL_DOWNLOAD_BACKGROUND="${MODEL_DOWNLOAD_BACKGROUND:-false}"

/opt/h3-template/scripts/setup_storage.sh

# Reconcile persistent custom_nodes to the image's known set. This makes reusing a
# network volume deterministic instead of preserving a broken old custom-node tree.
COMFYUI_DIR="$COMFYUI_DIR" /opt/h3-template/scripts/install_custom_nodes.sh

if [[ "$DOWNLOAD_H3_MODELS" == "true" ]]; then
  if [[ "$MODEL_DOWNLOAD_BACKGROUND" == "true" ]]; then
    echo "[boot] starting H3 model download in background; see $WORKSPACE_PATH/h3-model-download.log"
    nohup /opt/h3-template/scripts/download_models.sh >"$WORKSPACE_PATH/h3-model-download.log" 2>&1 &
  else
    echo "[boot] ensuring H3 models are present before ComfyUI starts"
    /opt/h3-template/scripts/download_models.sh
  fi
fi

# Copy workflow again after any custom-node reconciliation.
install -m 0644 /opt/h3-template/workflows/MiniMax_H3_R2VA_Custom_RunPod.json \
  "$COMFYUI_DIR/user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json"

cd "$COMFYUI_DIR"
DEFAULT_ARGS="--disable-auto-launch --cuda-malloc --async-offload --disable-dynamic-vram"
if python - <<'PY' >/dev/null 2>&1
try:
 import sageattention
except Exception:
 raise SystemExit(1)
PY
then
  DEFAULT_ARGS="$DEFAULT_ARGS --use-sage-attention"
fi

COMFYUI_EXTRA_ARGS="${COMFYUI_EXTRA_ARGS:-$DEFAULT_ARGS}"
echo "[boot] ComfyUI on :$COMFYUI_PORT"
echo "[boot] workflow: MiniMax_H3_R2VA_Custom_RunPod.json"
echo "[boot] args: $COMFYUI_EXTRA_ARGS"
python main.py --listen 0.0.0.0 --port "$COMFYUI_PORT" $COMFYUI_EXTRA_ARGS 2>&1 | tee "$WORKSPACE_PATH/comfyui.log"
