#!/usr/bin/env bash
set -euo pipefail

RESCUE_FLAG="/workspace/RESCUE_MODE"

echo "[rescue] Enabling rescue mode..."

touch "${RESCUE_FLAG}"

PID="$(pgrep -f "python .*main.py.*--port 8188" | head -n1 || true)"

if [[ -n "${PID}" ]]; then
  echo "[rescue] Stopping ComfyUI PID ${PID}..."
  kill "${PID}"
else
  echo "[rescue] ComfyUI is not currently running."
fi

echo
echo "[rescue] Rescue flag enabled."
echo "[rescue] Container should remain alive."
echo
echo "To leave rescue mode later:"
echo
echo "  rm -f /workspace/RESCUE_MODE"
echo
echo "Then restart the pod normally."
