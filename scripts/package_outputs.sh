#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="/workspace"
OUTPUT_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}/output"

ARCHIVE="${WORKSPACE}/OUTPUTS_RESCUE.tar"
PART_PREFIX="${ARCHIVE}.part-"
CHECKSUM_FILE="${WORKSPACE}/OUTPUTS_RESCUE.sha256"

echo "[outputs] Packaging:"
echo "${OUTPUT_DIR}"

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "[outputs] ERROR: output directory does not exist."
  exit 1
fi

rm -f \
  "${ARCHIVE}" \
  "${PART_PREFIX}"* \
  "${CHECKSUM_FILE}"

cd "${WORKSPACE}"

echo "[outputs] Creating TAR..."

tar -cf "${ARCHIVE}" \
  -C "$(dirname "${OUTPUT_DIR}")" \
  "$(basename "${OUTPUT_DIR}")"

echo "[outputs] Validating TAR..."

if ! tar -tf "${ARCHIVE}" >/dev/null; then
  echo "[outputs] ERROR: archive validation failed."
  exit 1
fi

echo "[outputs] TAR VALID."

echo "[outputs] Splitting into 200 MB chunks..."

split \
  -b 200M \
  -d \
  -a 2 \
  "${ARCHIVE}" \
  "${PART_PREFIX}"

echo "[outputs] Generating checksums..."

sha256sum "${PART_PREFIX}"* > "${CHECKSUM_FILE}"

echo
echo "======================================"
echo "OUTPUT BACKUP READY"
echo "======================================"

ls -lh "${PART_PREFIX}"*

echo
echo "Checksums:"
cat "${CHECKSUM_FILE}"

echo
echo "Archive:"
ls -lh "${ARCHIVE}"

echo
echo "[outputs] Done."
