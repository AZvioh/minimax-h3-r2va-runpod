#!/usr/bin/env bash
set -Eeuo pipefail
IMAGE="${1:-}"
[[ -n "$IMAGE" ]] || { echo "Usage: $0 registry/user/image:tag" >&2; exit 2; }
docker build -t "$IMAGE" .
docker push "$IMAGE"
echo "Pushed $IMAGE"
