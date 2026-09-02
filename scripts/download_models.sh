#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
MODELS_DIR="${COMFYUI_DIR}/models"

DOWNLOAD_H3_MODELS="${DOWNLOAD_H3_MODELS:-true}"
DOWNLOAD_TURBO_LORA="${DOWNLOAD_TURBO_LORA:-true}"

HF_REPO="${H3_HF_REPO:-Comfy-Org/MiniMax-H3}"
HF_TOKEN="${HF_TOKEN:-}"

DEFAULT_H3_QUANT="${DEFAULT_H3_QUANT:-int8}"

log() {
  echo "[models] $*"
}

fatal() {
  echo "[models] FATAL: $*" >&2
  exit 1
}

if [[ "${DOWNLOAD_H3_MODELS}" != "true" ]]; then
  log "DOWNLOAD_H3_MODELS=false; skipping H3 downloads."
  exit 0
fi

if ! command -v hf >/dev/null 2>&1; then
  fatal "'hf' command is not installed."
fi

mkdir -p \
  "${MODELS_DIR}/diffusion_models" \
  "${MODELS_DIR}/text_encoders" \
  "${MODELS_DIR}/vae" \
  "${MODELS_DIR}/loras"

case "${DEFAULT_H3_QUANT}" in
  int8)
    DIFFUSION_FILE="diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
    TEXT_ENCODER_FILE="text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    ;;

  fp8|nvfp4)
    # Current H3 setup uses the FP8 diffusion model for these profiles.
    # Keep the INT8 Qwen3-VL encoder as the conservative default.
    DIFFUSION_FILE="diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors"
    TEXT_ENCODER_FILE="text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    ;;

  bf16|false)
    DIFFUSION_FILE="diffusion_models/minimax_h3_ref2va_bf16.safetensors"
    TEXT_ENCODER_FILE="text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
    ;;

  *)
    fatal "Unsupported DEFAULT_H3_QUANT=${DEFAULT_H3_QUANT}"
    ;;
esac

REQUIRED_FILES=(
  "${DIFFUSION_FILE}"
  "${TEXT_ENCODER_FILE}"
  "vae/minimax_h3_video_vae_fp16.safetensors"
  "vae/minimax_h3_audio_vae_fp32.safetensors"
)

if [[ "${DOWNLOAD_TURBO_LORA}" == "true" ]]; then
  REQUIRED_FILES+=(
    "loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
  )
fi

download_hf_file() {
  local repo="$1"
  local file="$2"
  local local_dir="$3"
  local expected="$4"

  if [[ -s "${expected}" ]]; then
    log "Exists: ${expected}"
    return 0
  fi

  log "Downloading ${repo}:${file}"

  local attempt
  local success=0

  for attempt in 1 2 3 4 5; do
    args=(
      download
      "${repo}"
      "${file}"
      --local-dir
      "${local_dir}"
    )

    if [[ -n "${HF_TOKEN}" ]]; then
      args+=(--token "${HF_TOKEN}")
    fi

    if hf "${args[@]}"; then
      if [[ -s "${expected}" ]]; then
        success=1
        break
      fi
    fi

    log "Download attempt ${attempt}/5 failed for ${file}."

    if [[ "${attempt}" -lt 5 ]]; then
      sleep $((attempt * 5))
    fi
  done

  if [[ "${success}" != "1" ]]; then
    fatal "Download failed after 5 attempts: ${repo}:${file}"
  fi

  log "Ready: ${expected}"
}

log "Preparing MiniMax H3 model set."
log "Repository: ${HF_REPO}"
log "Quantization profile: ${DEFAULT_H3_QUANT}"

for rel in "${REQUIRED_FILES[@]}"; do
  download_hf_file \
    "${HF_REPO}" \
    "${rel}" \
    "${MODELS_DIR}" \
    "${MODELS_DIR}/${rel}"
done

# Optional additional Hugging Face LoRAs.
#
# Format:
#
# H3_EXTRA_HF_LORAS='owner/repo:path/model.safetensors;other/repo:foo/bar.safetensors'
#
# Files are copied into:
#
# /workspace/ComfyUI/models/loras/

if [[ -n "${H3_EXTRA_HF_LORAS:-}" ]]; then
  log "Processing additional Hugging Face LoRAs..."

  IFS=';' read -r -a EXTRA_LORA_SPECS <<< "${H3_EXTRA_HF_LORAS}"

  for spec in "${EXTRA_LORA_SPECS[@]}"; do
    spec="$(echo "${spec}" | xargs)"

    [[ -z "${spec}" ]] && continue

    if [[ "${spec}" != *:* ]]; then
      log "WARNING: invalid H3_EXTRA_HF_LORAS entry: ${spec}"
      continue
    fi

    repo="${spec%%:*}"
    file="${spec#*:}"

    if [[ -z "${repo}" || -z "${file}" ]]; then
      log "WARNING: invalid H3_EXTRA_HF_LORAS entry: ${spec}"
      continue
    fi

    filename="$(basename "${file}")"
    destination="${MODELS_DIR}/loras/${filename}"

    if [[ -s "${destination}" ]]; then
      log "Extra LoRA already exists: ${filename}"
      continue
    fi

    tmp_dir="$(mktemp -d /tmp/h3-extra-lora.XXXXXX)"

    cleanup_tmp() {
      rm -rf "${tmp_dir}"
    }

    trap cleanup_tmp RETURN

    expected_tmp="${tmp_dir}/${file}"

    download_hf_file \
      "${repo}" \
      "${file}" \
      "${tmp_dir}" \
      "${expected_tmp}"

    if [[ ! -s "${expected_tmp}" ]]; then
      fatal "Downloaded LoRA could not be found: ${expected_tmp}"
    fi

    cp "${expected_tmp}" "${destination}"

    if [[ ! -s "${destination}" ]]; then
      fatal "Failed to install LoRA: ${destination}"
    fi

    log "Installed extra LoRA: ${filename}"

    cleanup_tmp
    trap - RETURN
  done
fi

log "Required MiniMax H3 model set is ready."
