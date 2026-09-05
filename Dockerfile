# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=hearmeman/comfyui-base:cu130-comfy0.34.0-torch2.11.0
FROM ${BASE_IMAGE}

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        git \
        curl \
        ca-certificates \
        rsync \
        jq \
        aria2 \
        zip \
        unzip \
        procps \
        dnsutils && \
    rm -rf /var/lib/apt/lists/*

# Custom-node versions
ARG RGTHREE_REF=6b76ee6f2c5a007710b5a16f97c94330d6ecc871
ARG VHS_REF=4ee72c065db22c9d96c2427954dc69e7b908444b
ARG RIFE_REF=master
ARG UPSCALER_REF=master
ARG REFPACK_REF=main

COPY scripts/install_custom_nodes.sh /opt/h3-template/scripts/install_custom_nodes.sh

RUN chmod +x /opt/h3-template/scripts/install_custom_nodes.sh && \
    COMFYUI_DIR=/ComfyUI \
    RGTHREE_REF="${RGTHREE_REF}" \
    VHS_REF="${VHS_REF}" \
    RIFE_REF="${RIFE_REF}" \
    UPSCALER_REF="${UPSCALER_REF}" \
    REFPACK_REF="${REFPACK_REF}" \
    /opt/h3-template/scripts/install_custom_nodes.sh

# TensorRT / ONNX Runtime support
ARG ORT_INDEX_ARGS=""

RUN python -m pip uninstall -y \
        onnxruntime \
        onnxruntime-gpu \
        onnxruntime-directml \
        onnxruntime-openvino || true

RUN python -m pip install \
        --prefer-binary \
        onnxruntime-gpu \
        ${ORT_INDEX_ARGS}

# Hugging Face CLI + Xet
RUN python -m pip install \
        --prefer-binary \
        -U "huggingface_hub[hf_xet]"

# JupyterLab
RUN python -m pip install \
        --prefer-binary \
        -U jupyterlab

# Template files
COPY scripts /opt/h3-template/scripts
COPY README.md /opt/h3-template/README.md
COPY .env.example /opt/h3-template/.env.example

# Workflow directory intentionally exists even when no workflow is bundled.
RUN mkdir -p /opt/h3-template/workflows && \
    chmod +x /opt/h3-template/scripts/*.sh

EXPOSE 8188
EXPOSE 8888

CMD ["/opt/h3-template/scripts/start.sh"]
