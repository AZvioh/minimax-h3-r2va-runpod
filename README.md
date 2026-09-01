# OneClick — Custom ComfyUI MiniMax H3 R2VA

A RunPod image built **after and around the supplied `workflowmk(6).json`**, not a generic H3 template. The original H3 conditioning/sampling/decode architecture was retained, flattened onto the main canvas, and modernized where the old workflow had fragile dependencies.

## What changed from the supplied workflow

- Fixed 3-image loader bank → **MiniMax H3 Reference Pack**: upload 1–9 images, up to 3 videos, video soundtracks and standalone audio without rewiring the graph.
- Old QwenVL-Mod prompt-expander dependency → Reference Pack provider selector:
  - `none` (default): exact prompt passthrough, zero API key.
  - `openrouter`: optional multimodal auto-prompting.
  - `local`: optional OpenAI-compatible local server.
- Old `MiniMaxH3TurboSampler` + `MiniMaxH3TurboLoRA` custom nodes → current ComfyUI core sampler/sigma path and the current Ref2V Turbo LoRA.
- One hard-wired LoRA → **Power LoRA Loader** for adding/removing/stacking user H3 LoRAs, followed by the separate default Ref2V Turbo LoRA.
- Native H3 24 FPS output is independent from RIFE and upscaling.
- RIFE 48 FPS and upscale outputs are separate optional branches.

## Pinned base

`hearmeman/comfyui-base:cu130-comfy0.34.0-torch2.11.0`

This gives CUDA 13, Torch 2.11 and a known H3-capable ComfyUI instead of tracking `latest`.

## Models downloaded automatically

Default `DEFAULT_H3_QUANT=int8`:

| Folder | File |
|---|---|
| `models/diffusion_models` | `minimax_h3_ref2va_pruned_int8_convrot.safetensors` |
| `models/text_encoders` | `qwen3vl_32b_minimax_h3_int8_convrot.safetensors` |
| `models/vae` | `minimax_h3_video_vae_fp16.safetensors` |
| `models/vae` | `minimax_h3_audio_vae_fp32.safetensors` |
| `models/loras` | `minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` |

The downloads are persistent under `/workspace/ComfyUI/models`, so subsequent pods on the same network volume skip them.

## Daily use

1. Deploy the RunPod template.
2. First boot automatically prepares the persistent ComfyUI copy, reconciles the node packs, downloads missing H3 models, installs the workflow, and starts ComfyUI.
3. Open port **8188**.
4. Open **`MiniMax_H3_R2VA_Custom_RunPod`**.
5. In **MAIN H3 R2VA PROMPT + REFERENCES**, upload Picture 1. Add Pictures 2–9 only when you need them.
6. Add Video 1–3 and/or audio only when needed. The Reference Pack tiles show the exact `<Picture #>`, `<Video #>` and `<Audio #>` tags.
7. Type the request in the same Reference Pack node.
8. Leave `prompt_provider=none` for direct prompting. Switch to OpenRouter/local only if you want prompt expansion.
9. Add optional H3 LoRAs in **H3 LORAS — ADD / REMOVE / STACK HERE**. Put new `.safetensors` files in `/workspace/ComfyUI/models/loras`, refresh ComfyUI, and select them.
10. Generate. The green **NATIVE H3 — 24 FPS** output is the reliability path.

## One-click RunPod setup

### 1. Build and push the image

From this folder:

```bash
docker build -t YOUR_DOCKERHUB_USER/minimax-h3-r2va-oneclick:1 .
docker push YOUR_DOCKERHUB_USER/minimax-h3-r2va-oneclick:1
```

Use GHCR instead if preferred; the RunPod template only needs a pullable image.

### 2. Create the RunPod template

In **RunPod → Templates → New Template**:

- **Template name:** `OneClick - Custom MiniMax H3 R2VA`
- **Container image:** `YOUR_DOCKERHUB_USER/minimax-h3-r2va-oneclick:1`
- **Container disk:** 30 GB
- **HTTP port:** `8188`
- **Volume mount path:** `/workspace`
- **Network volume:** 100 GB minimum for INT8 + outputs/user LoRAs; use more if you collect LoRAs.
- **Docker command:** leave blank; the image CMD runs `start.sh`.

Environment variables (defaults already work):

```text
DOWNLOAD_H3_MODELS=true
DOWNLOAD_TURBO_LORA=true
DEFAULT_H3_QUANT=int8
MODEL_DOWNLOAD_BACKGROUND=false
INSTALL_OPTIONAL_RIFE=true
INSTALL_OPTIONAL_UPSCALER=true
HF_TOKEN=
OPENROUTER_API_KEY=
```

`MODEL_DOWNLOAD_BACKGROUND=false` means first boot waits until required models are complete before starting ComfyUI, preventing blank model dropdowns. Set it to `true` if you prefer the UI to appear immediately while models continue downloading.

### 3. Deploy

Choose a CUDA 13-capable NVIDIA GPU. 32 GB+ VRAM is recommended. The default INT8 profile is the most portable choice.

## LoRAs

### User LoRAs
Upload H3-compatible LoRAs to:

```text
/workspace/ComfyUI/models/loras/
```

Then refresh/restart ComfyUI. Use the **Power LoRA Loader** on the main canvas to add/remove multiple LoRAs and set their strengths.

### Turbo LoRA
The Ref2V Turbo LoRA is intentionally separate from the user LoRA bank:

`minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors`, strength `0.85`.

It is the default because the workflow is configured for the current four-step Turbo sigma schedule. Bypass that node only when you also intend to change sampling for a non-Turbo model/LoRA setup.

## Optional reference auto-prompting

The Reference Pack does not require an API key. Default `prompt_provider=none` passes your text through exactly.

For hosted auto-prompting, set `OPENROUTER_API_KEY` or `LLM_KEY` in the RunPod template and choose `openrouter` in the Reference Pack.

## Optional post-processing

- **Native:** ComfyUI core CreateVideo/SaveVideo, 24 FPS, H3 native audio. This is independent.
- **RIFE:** optional TensorRT 48 FPS branch.
- **Upscale:** optional TensorRT upscaler branch at 24 FPS.

If a future TensorRT/CUDA change breaks either optional pack, native H3 still runs.

## Persistence layout

```text
/workspace/
└── ComfyUI/
    ├── custom_nodes/
    ├── models/
    │   ├── diffusion_models/
    │   ├── text_encoders/
    │   ├── vae/
    │   ├── loras/
    │   ├── onnx/
    │   └── tensorrt/
    ├── input/
    ├── output/
    └── user/default/workflows/
        └── MiniMax_H3_R2VA_Custom_RunPod.json
```

## Troubleshooting

- **Workflow has missing MiniMaxH3ReferencePack:** inspect `custom_nodes/ComfyUI-MiniMaxRefPack` and rerun `scripts/install_custom_nodes.sh`.
- **Blank model dropdown:** check `/workspace/ComfyUI/models/...` and run `scripts/download_models.sh`.
- **RIFE/upscale fails:** bypass those optional nodes/groups; verify native 24 FPS generation first.
- **First boot downloads again:** make sure the network volume is mounted at `/workspace`.
- **Need a custom/uncensored H3 encoder:** place it in `models/text_encoders` and select it in the H3 text-encoder node. The template defaults to the official encoder for compatibility.

Run `COMFYUI_DIR=/workspace/ComfyUI /opt/h3-template/scripts/validate_install.sh` inside the pod to check the installation.
