#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
LORA_DIR="${CIVITAI_LORA_DIR:-${COMFY_DIR}/models/loras}"
TOKEN="${CIVITAI_API_TOKEN:-${civitai_token:-}}"
IDS_RAW="${CIVITAI_LORAS:-${LORAS_IDS_TO_DOWNLOAD:-}}"

mkdir -p "$LORA_DIR"

if [[ -z "${TOKEN}" ]]; then
  echo "[civitai] No token supplied. Set CIVITAI_API_TOKEN or civitai_token. Skipping."
  exit 0
fi

if [[ -z "${IDS_RAW}" ]]; then
  echo "[civitai] No version IDs supplied in CIVITAI_LORAS or LORAS_IDS_TO_DOWNLOAD. Skipping."
  exit 0
fi

IFS=',' read -r -a IDS <<< "$IDS_RAW"

for raw_id in "${IDS[@]}"; do
  id="$(echo "$raw_id" | xargs)"
  [[ -z "$id" ]] && continue

  meta_url="https://civitai.com/api/v1/model-versions/${id}"
  echo "[civitai] Resolving version ${id} ..."

  filename="$(curl -fsSL -H "Authorization: Bearer ${TOKEN}" "$meta_url" | python3 -c 'import sys,json; d=json.load(sys.stdin); files=d.get("files") or []; print(files[0].get("name","")) if files else print("")')"
  if [[ -z "$filename" ]]; then
    filename="civitai_${id}.safetensors"
  fi

  out="${LORA_DIR}/${filename}"
  if [[ -s "$out" ]]; then
    echo "[civitai] Already exists: $filename"
    continue
  fi

  tmp="${out}.part"
  dl_url="https://civitai.com/api/download/models/${id}?token=${TOKEN}"
  echo "[civitai] Downloading ${id} -> ${filename}"
  curl -fL --retry 5 --retry-delay 5 -C - "$dl_url" -o "$tmp"
  mv "$tmp" "$out"
  echo "[civitai] Saved: $out"
done

echo "[civitai] Done. Refresh/restart ComfyUI if new LoRAs do not appear immediately."
