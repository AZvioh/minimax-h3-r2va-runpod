#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
IMAGE_COMFYUI="${IMAGE_COMFYUI:-/ComfyUI}"
COMFYUI_DIR="${COMFYUI_DIR:-$WORKSPACE_PATH/ComfyUI}"
TEMPLATE_DIR="/opt/h3-template"

mkdir -p "$WORKSPACE_PATH"
if [[ ! -f "$COMFYUI_DIR/main.py" ]]; then
  echo "[storage] first boot: copying baked ComfyUI into persistent workspace"
  mkdir -p "$COMFYUI_DIR"
  rsync -a --delete "$IMAGE_COMFYUI/" "$COMFYUI_DIR/"
fi

mkdir -p "$COMFYUI_DIR"/{models,input,output,user/default/workflows}
mkdir -p "$COMFYUI_DIR/models"/{diffusion_models,text_encoders,vae,loras,onnx,tensorrt}

# Always install/update our workflow file; user-created workflows are untouched.
install -m 0644 "$TEMPLATE_DIR/workflows/MiniMax_H3_R2VA_Custom_RunPod.json" \
  "$COMFYUI_DIR/user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json"

echo "[storage] persistent ComfyUI: $COMFYUI_DIR"
