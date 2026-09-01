# Dependency Audit — source workflowmk(6).json

## Source workflow architecture
The supplied workflow contained a top-level UI plus one internal subgraph named `Image to Video (MiniMax H3)`. The core subgraph used native ComfyUI H3 conditioning/decoding but depended on older helper/custom nodes for prompt expansion and Turbo sampling.

## Required core in supplied workflow
- ComfyUI core: `UNETLoader`, `CLIPLoader`, `VAELoader`, `MiniMaxH3ReferenceToVideo`, `RandomNoise`, `BasicGuider`, `SamplerCustomAdvanced`, `VAEDecode`, `VAEDecodeAudio`, `CreateVideo`, `SaveVideo`, `ComfyMathExpression`, primitives/resolution selector.
- Models:
  - Ref2VA diffusion model
  - Qwen3-VL MiniMax H3 encoder
  - H3 video VAE
  - H3 audio VAE
  - Turbo LoRA

## Custom dependencies found in supplied workflow
- `huchukato/ComfyUI-QwenVL-Mod`: `AILab_QwenVL_Advanced`, `VRAMCleanup` — removed from final core; replaced by MiniMaxRefPack with passthrough (`prompt_provider=none`) or optional auto prompting.
- `Larryvrh/ComfyUI-MiniMax-H3-Turbo`: `MiniMaxH3TurboSampler`, `MiniMaxH3TurboLoRA` — removed; replaced by ComfyUI core `LoraLoaderModelOnly`, `KSamplerSelect`, `BetaSamplingScheduler`, `ExtendIntermediateSigmas`.
- `kijai/ComfyUI-KJNodes`: `WidgetToString` — removed from final workflow.
- `yolain/ComfyUI-Easy-Use`: prompt display node — removed; replaced by rgthree `Display Any`.
- `rgthree/rgthree-comfy`: retained and expanded for modular Power LoRA Loader.
- `Kosinkadink/ComfyUI-VideoHelperSuite`: retained only for optional 48 FPS/upscaled MP4 branches.
- `huchukato/ComfyUI-RIFE-TensorRT-Auto`: retained as optional.
- `huchukato/ComfyUI-Upscaler-TensorRT-Auto`: retained as optional.

## New required UI dependency
- `Hearmeman24/ComfyUI-MiniMaxRefPack` v0.3.5-compatible: one upload/reference manager for 1–9 images, up to 3 videos, video soundtracks and standalone audio. `prompt_provider=none` gives exact prompt passthrough with no key.

## Model changes
OLD diffusion filename in supplied UI:
`minimax_h3_ref2va_pruned_int8_convrot.safetensors` (some old embedded loader data also used an alternate HQ filename)

NEW default:
`minimax_h3_ref2va_pruned_int8_convrot.safetensors`

Reason: current official Comfy-Org file and current H3 workflows use this cross-GPU INT8 model.

OLD text encoder:
`qwen3vl_32b_h3_ultra_uncensored_heretic_int8_convrot.safetensors`

NEW default:
`qwen3vl_32b_minimax_h3_int8_convrot.safetensors`

Reason: current official H3 encoder is the conservative compatibility default. Custom/uncensored encoders can still be placed in `models/text_encoders` and selected manually.

OLD Turbo:
`minimax_h3_turbo_v4_step600_ema.safetensors` through custom MiniMaxH3Turbo nodes.

NEW Turbo:
`minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` at 0.85 through ComfyUI core `LoraLoaderModelOnly`.

Reason: current Ref2V-specific 4-step Turbo LoRA and current core sampling path remove a fragile custom-sampler dependency.
