# syntax=docker/dockerfile:1.7
# One-click MiniMax H3 R2VA RunPod image.
# Pinned base: CUDA 13 / Torch 2.11 / ComfyUI 0.34.0.

ARG BASE_IMAGE=hearmeman/comfyui-base:cu130-comfy0.34.0-torch2.11.0
FROM ${BASE_IMAGE}

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg git curl ca-certificates rsync jq aria2 \
    && rm -rf /var/lib/apt/lists/*

# Known-good revisions captured from the supplied workflow/current H3 workflow.
ARG RGTHREE_REF=6b76ee6f2c5a007710b5a16f97c94330d6ecc871
ARG VHS_REF=4ee72c065db22c9d96c2427954dc69e7b908444b
ARG RIFE_REF=51d88c0c0db49308dd3ade9edd4a5c1bcdf4ec72
ARG UPSCALER_REF=6b8951d7413b41d9639be91888ef65b63827b930

# MiniMaxRefPack currently exposes workflow version 0.3.5
# but upstream does not publish releases.
ARG REFPACK_REF=main

# Install only the required/lightweight custom nodes into the Docker image.
#
# IMPORTANT:
# RIFE TensorRT and TensorRT Upscaler are intentionally NOT installed here.
# Their CUDA/TensorRT packages are enormous and can exhaust GitHub Actions disk.
# start.sh can install them automatically on the RunPod instead.
COPY scripts/install_custom_nodes.sh /opt/h3-template/scripts/install_custom_nodes.sh

RUN chmod +x /opt/h3-template/scripts/install_custom_nodes.sh && \
    COMFYUI_DIR=/ComfyUI \
    RGTHREE_REF=${RGTHREE_REF} \
    VHS_REF=${VHS_REF} \
    RIFE_REF=${RIFE_REF} \
    UPSCALER_REF=${UPSCALER_REF} \
    REFPACK_REF=${REFPACK_REF} \
    INSTALL_OPTIONAL_RIFE=false \
    INSTALL_OPTIONAL_UPSCALER=false \
    /opt/h3-template/scripts/install_custom_nodes.sh

# GPU ONNX Runtime used by relevant nodes.
RUN python -m pip uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true; \
    python -m pip install --no-cache-dir --prefer-binary onnxruntime-gpu

# Model downloader tooling.
# Large H3 model files are NOT downloaded into this Docker image.
RUN python -m pip install --no-cache-dir --prefer-binary -U "huggingface_hub[hf_xet]"

COPY workflows /opt/h3-template/workflows
COPY scripts /opt/h3-template/scripts
COPY README.md /opt/h3-template/README.md
COPY .env.example /opt/h3-template/.env.example

RUN chmod +x /opt/h3-template/scripts/*.sh

EXPOSE 8188

CMD ["/opt/h3-template/scripts/start.sh"]
