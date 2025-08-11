
# WASM 2D Game Engine

## Rendering To-Do:

add a means to hint the texture scaling/sampling mode, 
    since we need nearest neighbor in order for pixel graphics to not look like shit

try to add support for colormapped images/shader somewhat cleanly.

try to add some better way of batching rendering, though this is less of a concern for now

fix rendering of tilemap outlines and tilemaps themselves
probably render tilemaps out to textures and then blit those textures all at once, if we are still getting weird artifacts after fixing the scaling/sampling

maybe we should even render all of game to a texture so that we can scale it more nicely or apply post-processing shader like scanlines or somethin

## General To-Do:

fix the editor
test ability to save and load levels

fix wasm crash fixer so that we don't need the additional declaration in runtime_support

