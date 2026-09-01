# Validation checklist

## Build-time
- [ ] Docker image builds from the pinned CUDA13/Torch2.11/ComfyUI0.34.0 base.
- [ ] Required custom nodes install: MiniMaxRefPack and rgthree.
- [ ] Optional VideoHelperSuite/RIFE/Upscaler failures do not remove the native H3 path.
- [ ] `onnxruntime` resolves `CUDAExecutionProvider` if optional TensorRT branches are enabled.

## First boot
- [ ] `/workspace/ComfyUI/main.py` exists.
- [ ] Workflow appears at `user/default/workflows/MiniMax_H3_R2VA_Custom_RunPod.json`.
- [ ] Required INT8 H3 model, encoder, video VAE, audio VAE and Ref2V Turbo LoRA exist.
- [ ] ComfyUI opens on port 8188.

## Workflow
- [ ] MiniMaxH3ReferencePack accepts a single image without graph edits.
- [ ] Add 2–9 images and verify visible tags remain `<Picture 1..n>`.
- [ ] Add one reference video and verify `<Video 1>`.
- [ ] Toggle its soundtrack and verify audio numbering shown by RefPack.
- [ ] Add standalone audio and verify `<Audio #>`.
- [ ] Set prompt provider `none`; generated-prompt display exactly matches direction text.
- [ ] Optional: set OpenRouter provider and verify generated prompt changes.
- [ ] Add an H3-compatible LoRA in Power LoRA Loader and adjust strength.
- [ ] Native 24 FPS output renders with synchronized H3 audio while RIFE/upscale are bypassed/absent.
- [ ] Optional RIFE branch produces 48 FPS output.
- [ ] Optional upscale branch produces a separate 24 FPS upscaled output.

## Persistence
- [ ] Restart pod on same network volume; required large models are skipped, not re-downloaded.
- [ ] User-added LoRAs remain in `/workspace/ComfyUI/models/loras`.
- [ ] Outputs remain in `/workspace/ComfyUI/output`.
