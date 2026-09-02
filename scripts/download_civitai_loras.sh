#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
LORA_DIR="${CIVITAI_LORA_DIR:-${COMFY_DIR}/models/loras}"

TOKEN="${CIVITAI_API_TOKEN:-${civitai_token:-}}"
IDS_RAW="${CIVITAI_LORAS:-${LORAS_IDS_TO_DOWNLOAD:-}}"

mkdir -p "${LORA_DIR}"

log() {
  echo "[civitai] $*"
}

if [[ -z "${TOKEN}" ]]; then
  log "No token supplied. Set CIVITAI_API_TOKEN or civitai_token. Skipping."
  exit 0
fi

if [[ -z "${IDS_RAW}" ]]; then
  log "No version IDs supplied in CIVITAI_LORAS or LORAS_IDS_TO_DOWNLOAD. Skipping."
  exit 0
fi

IFS=',' read -r -a IDS <<< "${IDS_RAW}"

for raw_id in "${IDS[@]}"; do
  id="$(echo "${raw_id}" | xargs)"

  [[ -z "${id}" ]] && continue

  meta_url="https://civitai.com/api/v1/model-versions/${id}"

  log "Resolving version ${id} ..."

  filename="$(
    curl \
      --fail \
      --silent \
      --show-error \
      --location \
      --retry 5 \
      --retry-delay 5 \
      -H "Authorization: Bearer ${TOKEN}" \
      "${meta_url}" \
    | python3 -c '
import sys, json

data = json.load(sys.stdin)
files = data.get("files") or []

if not files:
    print("")
    raise SystemExit

preferred = None

for f in files:
    name = f.get("name", "")
    if name.lower().endswith(".safetensors"):
        preferred = name
        break

if preferred is None:
    preferred = files[0].get("name", "")

print(preferred)
'
  )"

  if [[ -z "${filename}" ]]; then
    filename="civitai_${id}.safetensors"
  fi

  out="${LORA_DIR}/${filename}"
  tmp="${out}.part"

  if [[ -s "${out}" ]]; then
    log "Already exists: ${filename}"
    continue
  fi

  dl_url="https://civitai.com/api/download/models/${id}"

  log "Downloading ${id} -> ${filename}"

  curl \
    --fail \
    --location \
    --retry 5 \
    --retry-delay 5 \
    --continue-at - \
    -H "Authorization: Bearer ${TOKEN}" \
    "${dl_url}" \
    -o "${tmp}"

  if [[ ! -s "${tmp}" ]]; then
    log "ERROR: Download produced an empty file for version ${id}"
    rm -f "${tmp}"
    exit 1
  fi

  mv "${tmp}" "${out}"

  log "Saved: ${out}"
done

log "Done. Refresh or restart ComfyUI if new LoRAs do not appear immediately."
