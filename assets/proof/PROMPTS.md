# Draft asset prompt set

Generated using the built-in `image_gen` tool on2026-10-25. Selected outputs were
copied into this directory; raw originals remain in the tool's generated_images
storage. These are a first moving-scene sample, not bulk production art.

## Car atlas

Use case: stylized-concept. Asset type: production draft game SPRITE ATLAS,
transparent background. Make a single PNG canvas exactly1536x1024, arranged as a
precise3-column2-row grid of six equal512x512 cells, no grid lines and no text.
In each cell draw the same white2019 Chevrolet Corvette C7 Stingray Coupe with
removable targa roof off, seen from behind by an arcade racing chase camera.
Cartoon hand-painted cel-shaded racing art; convincing sculpted contours, dark
open cabin, visible seats/headrests, angular four red tail lamps, black treaded
tires, softly painted body shading without ground shadow, blue/gold reflections.
Modern lively animated-cartoon interpretation of1990s SNES racing sprites;
gently diffused pixel-like edges, not photorealistic or block rectangles, no
branding text/logos. Face away from viewer in every frame. Reading-order poses:
rear straight flat; rear turning left12degrees; rear turning right12degrees;
rear ascending hill showing slightly more bumper underside; rear descending
hill showing more cabin; rear rightward skid. Keep vehicles inside each cell,
centerx256, tire-ground contacty420, width about390px/height260px, consistent
lighting from upper left, scale, anchors and identity. Actual transparent pixels
outside vehicles; no background, road, checkerboard, plane, labels, border,
extra cars or detached wheels.

## Scenery atlas

Use case: stylized-concept. Racing scenery sprite atlas on actual transparent
background,1536x1024, exact3-column2-row grid, six512x512 cells, no grid/text.
Coherent lively hand-painted cartoon art with diffused pixel-style edges, shaded
organic forms and warm upper-left late-afternoon sunlight. Near-ground roadside
view for depth-scaled racing billboards. Reading order: lush rounded broadleaf
tree with layered green foliage and brown trunk; irregular layered evergreen
pine; bent California palm; charming5-storey American brick/stone corner building
with windows/fire escape/awning; small colorful roadside garage diner with curved
canopy/warm windows/tiled roof/plants; flowering shrub with long grasses and
orange wildflowers. Each full object inside its cell with25px transparent margin,
ground baseliney470. No ground plane or cast shadow. Rich silhouettes, material
texture and drawn architecture, not flat rectangles or geometric icons. Never
overlap cells; no checkerboard, logos, labels or watermark.

## Panoramic hills

Use case: stylized-concept. Horizontally repeating racing-game parallax layer,
requested1536x512 transparent PNG. Continuous panoramic band of softly painted
blue-green American Appalachian hills with a small present-day city in the
valley, leafy foothills and rounded tan outcrops. Lively modern cartoon painting,
atmospheric layered texture, diffused pixel-like edges, restrained distant detail,
warm late-afternoon rim light. Silhouette tops mostlyy150–290, lower land fills
to bottomy512; above the silhouette transparent, no sky/clouds/sun. Left/right
edges match for scrolling. Overlapping ridges, no repeated triangle mountains,
varied city silhouettes, no road/cars/foreground trees/words/logos/border.

## Inspection

Both atlases are1536x1024 RGBA; the backdrop output is2172x724 RGBA. All have
actual zero-alpha background pixels and feathered partial-alpha edges. Atlas
pose identity, seams, pivots, lighting and motion still require in-game review.
