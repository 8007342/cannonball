# Licence register (generative models)

Models the local asset pipeline may use. **Approved by the user on 2026-11-20**
(agent session; the approval covered the Apache-2.0/MIT set, SDXL under
CreativeML OpenRAIL++-M and the OpenRAIL-M LoRAs/adapters, and allowed the
agents to pick between them, recording pick reasons the user can override).
Acknowledgement records: `licences/acknowledgements/<licence>.yaml`; licence
texts: `licences/texts/`.

The studio refuses any model whose licence is not admitted (`model_refused`) and
never downloads without the user's consent token, so this register lists only
weights already on the host. Repos/revisions per output are recorded in each
studio provenance sidecar and copied into `art/families/<family>-runs.json`.

| Model (file) | Source repo (studio pin) | Licence | Used by | Status |
|---|---|---|---|---|
| FLUX.2-klein 4B (`flux-2-klein-4b.safetensors`, `qwen_3_4b.safetensors`, `flux2-vae.safetensors`) | Comfy-Org/Flux-2-Klein-4B (black-forest-labs/FLUX.2-klein-4B) | Apache-2.0 | `art/workflows/sprite-flux2-matte.json`, `texture-flux2-tile.json` | **in use** (all organic sprites, vistas, textures) |
| BiRefNet (`birefnet/model.safetensors`) | ZhengPeng7/BiRefNet | MIT | `sprite-flux2-matte.json`, `structure-paint-qwen.json` (in-graph matte) | **in use** |
| Qwen-Image-Edit 2511 (`qwen_image_edit_2511_fp8mixed.safetensors`) + text encoder `qwen_2.5_vl_7b_fp8_scaled` + `qwen_image_vae` | Comfy-Org/Qwen-Image-Edit, Comfy-Org/Qwen-Image | Apache-2.0 | `structure-paint-qwen.json` (structure paint, animation frames), `art/rigs/workflows/*` | **in use** |
| Qwen-Image-Edit-2511 Lightning 4-step LoRA | lightx2v/Qwen-Image-Edit-2511-Lightning | Apache-2.0 | same | **in use** |
| SDXL base 1.0 (`sdxl-full/sd_xl_base_1.0.safetensors`) | stabilityai/stable-diffusion-xl-base-1.0 | CreativeML OpenRAIL++-M | `sprite-sdxl-layerdiffuse.json` | approved, validated, alternative path |
| pixel-art-xl LoRA | nerijs/pixel-art-xl | CreativeML OpenRAIL-M | `sprite-sdxl-layerdiffuse.json` | approved, alternative path |
| LayerDiffuse SDXL (`layer_xl_transparent_attn/conv`, `vae_transparent_decoder`) | LayerDiffusion/layerdiffusion-v1 | CreativeML OpenRAIL-M | `sprite-sdxl-layerdiffuse.json` | approved, alternative path |
| SDXL-Lightning 4-step (`sdxl_lightning_4step.safetensors`) | ByteDance/SDXL-Lightning | CreativeML OpenRAIL++-M (SDXL-Lightning) | not used yet | approved |
| ControlNet-Union SDXL promax | xinsir/controlnet-union-sdxl-1.0 | Apache-2.0 | not used yet (candidate for depth-guided structures) | approved |
| IP-Adapter plus SDXL ViT-H + CLIP ViT-H image encoder | h94/IP-Adapter, laion CLIP-ViT-H | Apache-2.0 (studio pin) | not used yet (candidate for style locking) | approved |
| FLUX.1-schnell (`image.generate` tier I3) | black-forest-labs/FLUX.1-schnell | Apache-2.0 | smoke test only (2026-11-20 barn) | approved |
| SDXL VAE (`sdxl_vae.safetensors`) | madebyollin/sdxl-vae-fp16-fix | MIT | not used | approved |

## Why FLUX.2-klein is the default sprite model (agent pick, overridable)

- Apache-2.0 and already on disk; 4 steps, ~3-4 s per 1 MP image warm on the
  24 GB host, so 3 candidates per item cost ~12 s.
- On the 2026-11-20 probes it matched the proof art (`assets/proof/`) best:
  painterly cartoon shading with soft pixel-like edges, readable silhouettes,
  correct "flat white background" compliance (which BiRefNet then mattes
  cleanly in the same graph).
- SDXL + pixel-art-xl + LayerDiffuse gives native alpha but a blockier,
  hard-pixel look farther from the proof style; it stays as a validated
  alternative (`art/workflows/sprite-sdxl-layerdiffuse.json`).

## Obligations carried into the project

- OpenRAIL(-M/++-M) use-based restrictions apply to anything generated with
  SDXL/LoRAs/LayerDiffuse; generated scenery and textures are within them.
- Apache-2.0/MIT: keep this register and the texts with the repository.
- Generated outputs carry no third-party trademarks or likenesses: prompts
  avoid brand names and real people.
