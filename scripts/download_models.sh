#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
MODELS="$COMFYUI_DIR/models"
DOWNLOAD_H3_MODELS="${DOWNLOAD_H3_MODELS:-true}"
DOWNLOAD_TURBO_LORA="${DOWNLOAD_TURBO_LORA:-true}"
HF_REPO="${H3_HF_REPO:-Comfy-Org/MiniMax-H3}"
HF_TOKEN="${HF_TOKEN:-}"
DEFAULT_H3_QUANT="${DEFAULT_H3_QUANT:-int8}"

[[ "$DOWNLOAD_H3_MODELS" == "true" ]] || { echo "[models] DOWNLOAD_H3_MODELS=false; skipping"; exit 0; }

mkdir -p "$MODELS"/{diffusion_models,text_encoders,vae,loras}

case "$DEFAULT_H3_QUANT" in
  int8)
    DIFFUSION="diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
    TEXT_ENCODER="text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    ;;
  fp8|nvfp4)
    # Current upstream template uses FP8 diffusion for both fp8 and nvfp4 profiles;
    # the official INT8 encoder remains the conservative cross-GPU default.
    DIFFUSION="diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors"
    TEXT_ENCODER="text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    ;;
  bf16|false)
    DIFFUSION="diffusion_models/minimax_h3_ref2va_bf16.safetensors"
    TEXT_ENCODER="text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    ;;
  *) echo "Unsupported DEFAULT_H3_QUANT=$DEFAULT_H3_QUANT" >&2; exit 2 ;;
esac

FILES=(
  "$DIFFUSION"
  "$TEXT_ENCODER"
  "vae/minimax_h3_video_vae_fp16.safetensors"
  "vae/minimax_h3_audio_vae_fp32.safetensors"
)
if [[ "$DOWNLOAD_TURBO_LORA" == "true" ]]; then
  FILES+=("loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors")
fi

for rel in "${FILES[@]}"; do
  target="$MODELS/$rel"
  if [[ -s "$target" ]]; then
    echo "[models] exists: $rel"
    continue
  fi
  echo "[models] downloading: $rel"
  # hf/xet handles resume and large-file chunking. Retry transient failures.
  ok=0
  for attempt in 1 2 3 4; do
    args=(download "$HF_REPO" "$rel" --local-dir "$MODELS")
    [[ -n "$HF_TOKEN" ]] && args+=(--token "$HF_TOKEN")
    if hf "${args[@]}"; then ok=1; break; fi
    echo "[models] retry $attempt for $rel" >&2
    sleep $((attempt * 5))
  done
  [[ "$ok" == 1 && -s "$target" ]] || { echo "[models] FATAL download failed: $rel" >&2; exit 1; }
done

# Optional user-specified HF LoRA files, semicolon-separated repo:file pairs.
# Example: H3_EXTRA_HF_LORAS='owner/repo:path/a.safetensors;other/repo:b.safetensors'
if [[ -n "${H3_EXTRA_HF_LORAS:-}" ]]; then
  IFS=';' read -ra specs <<< "$H3_EXTRA_HF_LORAS"
  for spec in "${specs[@]}"; do
    repo="${spec%%:*}"; file="${spec#*:}"
    [[ "$repo" != "$file" ]] || { echo "[models] bad H3_EXTRA_HF_LORAS item: $spec"; continue; }
    dest="$MODELS/loras/$(basename "$file")"
    [[ -s "$dest" ]] && { echo "[models] extra LoRA exists: $dest"; continue; }
    args=(download "$repo" "$file" --local-dir /tmp/h3-extra-lora)
    [[ -n "$HF_TOKEN" ]] && args+=(--token "$HF_TOKEN")
    rm -rf /tmp/h3-extra-lora
    hf "${args[@]}"
    cp "/tmp/h3-extra-lora/$file" "$dest"
    rm -rf /tmp/h3-extra-lora
  done
fi

echo "[models] required H3 model set ready"
