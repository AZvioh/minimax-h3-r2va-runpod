#!/usr/bin/env bash
set -Eeuo pipefail
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
fail=0
need() { [[ -e "$1" ]] || { echo "MISSING: $1" >&2; fail=1; }; }

need "$COMFYUI_DIR/main.py"
need "$COMFYUI_DIR/user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json"
need "$COMFYUI_DIR/custom_nodes/ComfyUI-MiniMaxRefPack"
need "$COMFYUI_DIR/custom_nodes/rgthree-comfy"

if [[ "${DOWNLOAD_H3_MODELS:-true}" == "true" ]]; then
  case "${DEFAULT_H3_QUANT:-int8}" in
    int8) need "$COMFYUI_DIR/models/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors" ;;
    fp8|nvfp4) need "$COMFYUI_DIR/models/diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors" ;;
    bf16|false) need "$COMFYUI_DIR/models/diffusion_models/minimax_h3_ref2va_bf16.safetensors" ;;
  esac
  need "$COMFYUI_DIR/models/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
  need "$COMFYUI_DIR/models/vae/minimax_h3_video_vae_fp16.safetensors"
  need "$COMFYUI_DIR/models/vae/minimax_h3_audio_vae_fp32.safetensors"
fi

python - <<'PY'
import json, os
p=os.path.join(os.environ.get('COMFYUI_DIR','/workspace/ComfyUI'),'user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json')
w=json.load(open(p))
required={'MiniMaxH3ReferenceToVideo','MiniMaxH3ReferencePack','LoraLoaderModelOnly','SamplerCustomAdvanced','VAEDecodeAudio','CreateVideo'}
types={n['type'] for n in w['nodes']}
missing=required-types
assert not missing, f'workflow missing required node types: {missing}'
print('[validate] workflow JSON and required node types OK')
PY

[[ "$fail" == 0 ]] || exit 1
echo "[validate] install OK"
