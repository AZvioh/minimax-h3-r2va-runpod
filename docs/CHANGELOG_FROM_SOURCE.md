# Changes from workflowmk(6).json

This project intentionally keeps the supplied workflow as the historical source file under `source/`.

## Preserved
- Native `MiniMaxH3ReferenceToVideo` conditioning architecture.
- Joint H3 video/audio latent.
- Separate video/audio VAE decoding.
- Native 24 FPS H3 video with synchronized audio.
- Resolution and duration controls.
- Optional RIFE interpolation concept.
- Optional TensorRT upscale concept.

## Modernized
- Internal subgraph was flattened onto the main canvas so critical settings are visible.
- Three fixed `LoadImage` nodes were replaced with `MiniMaxH3ReferencePack`.
- H3 reference sockets expanded to the current full layout: 9 image, 3 video, 3 video-soundtrack audio, 3 standalone audio.
- Old QwenVL-Mod auto-prompt node removed. RefPack now owns prompting and defaults to `prompt_provider=none` for exact no-key passthrough.
- `MiniMaxH3TurboSampler` custom node replaced with core `KSamplerSelect` + `BetaSamplingScheduler` + `ExtendIntermediateSigmas`.
- Old custom `MiniMaxH3TurboLoRA` replaced by core `LoraLoaderModelOnly` using the Ref2V-specific 4-step Turbo LoRA.
- Added rgthree Power LoRA Loader before Turbo to support user-added/stacked generation-model LoRAs.
- Official H3 text encoder is the default instead of the old custom Heretic encoder filename.
- Native 24 FPS output is now structurally independent of RIFE/upscale.
- RIFE and upscale branches now produce separate outputs instead of forming a single mandatory chain.
