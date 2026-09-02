# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=hearmeman/comfyui-base:cu130-comfy0.34.0-torch2.11.0
FROM ${BASE_IMAGE}

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg \
      git \
      curl \
      ca-certificates \
      rsync \
      jq \
      aria2 \
    && rm -rf /var/lib/apt/lists/*

# Pinned custom-node refs for reproducible builds
ARG RGTHREE_REF=6b76ee6f2c5a007710b5a16f97c94330d6ecc871
ARG VHS_REF=4ee72c065db22c9d96c2427954dc69e7b908444b
ARG RIFE_REF=51d88c0c0db49308dd3ade9edd4a5c1bcdf4ec72
ARG UPSCALER_REF=6b8951d7413b41d9639be91888ef65b63827b930
ARG REFPACK_REF=main

# Install custom nodes and their dependencies during Docker build.
# Do NOT reinstall these again at pod startup.
COPY scripts/install_custom_nodes.sh /opt/h3-template/scripts/install_custom_nodes.sh

RUN chmod +x /opt/h3-template/scripts/install_custom_nodes.sh && \
    COMFYUI_DIR=/ComfyUI \
    RGTHREE_REF="${RGTHREE_REF}" \
    VHS_REF="${VHS_REF}" \
    RIFE_REF="${RIFE_REF}" \
    UPSCALER_REF="${UPSCALER_REF}" \
    REFPACK_REF="${REFPACK_REF}" \
    INSTALL_OPTIONAL_RIFE=true \
    INSTALL_OPTIONAL_UPSCALER=true \
    /opt/h3-template/scripts/install_custom_nodes.sh

# Keep only GPU ONNX Runtime
ARG ORT_INDEX_ARGS=""
RUN python -m pip uninstall -y onnxruntime onnxruntime-gpu 2>/dev/null || true && \
    python -m pip install --prefer-binary onnxruntime-gpu ${ORT_INDEX_ARGS}

# Faster Hugging Face downloads
RUN python -m pip install --prefer-binary -U "huggingface_hub[hf_xet]"

# Copy runtime files last so edits to workflows/scripts do not invalidate
# the expensive custom-node installation layers unnecessarily.
COPY workflows /opt/h3-template/workflows
COPY scripts /opt/h3-template/scripts
COPY README.md /opt/h3-template/README.md
COPY .env.example /opt/h3-template/.env.example

RUN chmod +x /opt/h3-template/scripts/*.sh

EXPOSE 8188

CMD ["/opt/h3-template/scripts/start.sh"]
