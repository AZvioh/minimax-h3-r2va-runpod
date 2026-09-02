#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
WORKFLOW_PATH="${COMFYUI_DIR}/user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json"

fail=0

log() {
  echo "[validate] $*"
}

need() {
  local path="$1"

  if [[ ! -e "${path}" ]]; then
    echo "[validate] MISSING: ${path}" >&2
    fail=1
  else
    log "Found: ${path}"
  fi
}

# Core ComfyUI
need "${COMFYUI_DIR}/main.py"

# Required custom nodes
need "${COMFYUI_DIR}/custom_nodes/ComfyUI-MiniMaxRefPack"
need "${COMFYUI_DIR}/custom_nodes/rgthree-comfy"

# Optional node packs expected when enabled
if [[ "${INSTALL_OPTIONAL_RIFE:-true}" == "true" ]]; then
  need "${COMFYUI_DIR}/custom_nodes/ComfyUI-RIFE-TensorRT-Auto"
fi

if [[ "${INSTALL_OPTIONAL_UPSCALER:-true}" == "true" ]]; then
  need "${COMFYUI_DIR}/custom_nodes/ComfyUI-Upscaler-TensorRT-Auto"
fi

# Required H3 models
if [[ "${DOWNLOAD_H3_MODELS:-true}" == "true" ]]; then
  case "${DEFAULT_H3_QUANT:-int8}" in
    int8)
      need "${COMFYUI_DIR}/models/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
      ;;

    fp8|nvfp4)
      need "${COMFYUI_DIR}/models/diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors"
      ;;

    bf16|false)
      need "${COMFYUI_DIR}/models/diffusion_models/minimax_h3_ref2va_bf16.safetensors"
      ;;

    *)
      echo "[validate] Unsupported DEFAULT_H3_QUANT=${DEFAULT_H3_QUANT}" >&2
      fail=1
      ;;
  esac

  need "${COMFYUI_DIR}/models/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
  need "${COMFYUI_DIR}/models/vae/minimax_h3_video_vae_fp16.safetensors"
  need "${COMFYUI_DIR}/models/vae/minimax_h3_audio_vae_fp32.safetensors"

  if [[ "${DOWNLOAD_TURBO_LORA:-true}" == "true" ]]; then
    need "${COMFYUI_DIR}/models/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
  fi
fi

if [[ "${fail}" != "0" ]]; then
  echo "[validate] Install validation FAILED." >&2
  exit 1
fi

# Workflow is optional.
if [[ -f "${WORKFLOW_PATH}" ]]; then
  log "Bundled workflow found; validating JSON..."

  python - <<'PY'
import json
import os
import sys

comfy = os.environ.get("COMFYUI_DIR", "/workspace/ComfyUI")
path = os.path.join(
    comfy,
    "user",
    "default",
    "workflows",
    "MiniMax_H3_R2VA_Custom_RunPod.json",
)

try:
    with open(path, "r", encoding="utf-8") as f:
        workflow = json.load(f)
except Exception as exc:
    print(f"[validate] ERROR: failed to load workflow JSON: {exc}", file=sys.stderr)
    raise SystemExit(1)

nodes = workflow.get("nodes")

if not isinstance(nodes, list):
    print("[validate] ERROR: workflow does not contain a valid nodes list.", file=sys.stderr)
    raise SystemExit(1)

print("[validate] Workflow JSON OK.")
PY

else
  log "No bundled workflow present. That's OK; drag/drop your workflow manually."
fi

log "Install OK."
