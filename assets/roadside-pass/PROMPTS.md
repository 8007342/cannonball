# Sparse roadside-business sample

Generated 2026-10-25 using the built-in image generation tool. The existing
`assets/proof/scenery-atlas.png` was a style reference, not an edit target.
Original output is retained as `business-atlas.png`, RGBA1254×1254. No real brands,
text or copied logos were requested. Four pictorial businesses: fuel, burger,
motel and diner/B&B. Runtime copies measured source regions into512-unit cells
with aspect preserved; source art is not stretched independently in x/y.

This is one coherent review sheet, not a nationwide production pack. Shadows and
small plants are attached to the sprites; ramp clearance uses full footprints.
Source crops and ground anchors live in `ProofArt.businessSources` and
`ProofArt.sceneryGround`. Alpha includes genuinely transparent areas. Fine glow
and soft edge artifacts remain subject to moving review.

## Exact prompt

Create one coherent 2x2 square sprite atlas for Cannonball, a modern colorful soft-edged pixel-painted OutRun/Baja-like arcade road-trip racer. Reference image is STYLE REFERENCE ONLY: match its rich warm painterly pixel texture, soft animated-cartoon edges, grounded three-quarter roadside perspective, crisp readable silhouettes, upper-left afternoon illumination, warm window glow. Four DISTINCT complete standalone roadside businesses in four EXACT equal cells, generous transparent gutters. Top-left: adorable independent gasoline service station with red/cream canopy, two visible pumps, tall pictorial sign with a fuel-pump icon. Top-right: small red-roof burger drive-in with striped awning, giant generic burger-shaped roadside emblem, a couple of patio umbrellas. Bottom-left: cozy two-storey roadside motel with blue roof, small garden and a crescent-moon-plus-bed pictorial sign. Bottom-right: charming retro roadside diner/bed-and-breakfast with cream clapboard porch, teal trim, a coffee-cup pictorial sign. All original designs, no real brands, absolutely NO letters, numbers, writing, text labels, watermark, or copied logos. Front facades face viewer and slightly right, each entire building + sign fits comfortably inside its own cell, no cropping, no touching cell boundaries. Each cell ground/shadow baseline at about 90 percent of cell height; sky/environment/background genuinely transparent, just tiny contact shadow and small attached plants. Similar scale and detail to reference convenience store, not flat geometric vectors, not glossy crisp 3D renders, not photo-realism. Output one transparent square PNG sprite sheet at high resolution.

## Saved source

`assets/roadside-pass/business-atlas.png` copied from the built-in output under
`/home/forge/.codex/generated_images/01a170e8-4215-7262-bbfe-73a8728f3a4d/`.
The project copy is durable; runtime never reads the external generation folder.
