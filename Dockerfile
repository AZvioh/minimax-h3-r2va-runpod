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
# MiniMaxRefPack currently exposes workflow version 0.3.5 but upstream does not publish releases.
# Keep this overridable so a known commit can be supplied at build time later.
ARG REFPACK_REF=main

COPY scripts/install_custom_nodes.sh /opt/h3-template/scripts/install_custom_nodes.sh
RUN chmod +x /opt/h3-template/scripts/install_custom_nodes.sh && \
    COMFYUI_DIR=/ComfyUI \
    RGTHREE_REF=${RGTHREE_REF} VHS_REF=${VHS_REF} RIFE_REF=${RIFE_REF} \
    UPSCALER_REF=${UPSCALER_REF} REFPACK_REF=${REFPACK_REF} \
    INSTALL_OPTIONAL_RIFE=true INSTALL_OPTIONAL_UPSCALER=true \
    /opt/h3-template/scripts/install_custom_nodes.sh

# A node requirements file can install CPU onnxruntime last; force GPU provider afterward.
RUN python -m pip uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true; \
    python -m pip install --prefer-binary onnxruntime-gpu $ORT_INDEX_ARGS

# Model downloader tooling. hf_xet helps with the very large H3 files.
RUN python -m pip install --prefer-binary -U "huggingface_hub[hf_xet]"

COPY workflows /opt/h3-template/workflows
COPY scripts /opt/h3-template/scripts
COPY README.md /opt/h3-template/README.md
COPY .env.example /opt/h3-template/.env.example
RUN chmod +x /opt/h3-template/scripts/*.sh

EXPOSE 8188
CMD ["/opt/h3-template/scripts/start.sh"]
