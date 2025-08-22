
# WASM 2D Game Engine

## Rendering To-Do:

add a means to hint the texture scaling/sampling mode, 
    since we need nearest neighbor in order for pixel graphics to not look like shit

try to add support for colormapped images/shader somewhat cleanly.

try to add some better way of batching rendering, though this is less of a concern for now
    even less of an issue if we properly construct a texture atlas

fix rendering of tilemap outlines and tilemaps themselves
probably render tilemaps out to textures and then blit those textures all at once, if we are still getting weird artifacts after fixing the scaling/sampling

maybe we should even render all of game to a texture so that we can scale it more nicely or apply post-processing shader like scanlines or somethin

## General To-Do:

test ability to save and load levels

Should be able to build without editor enabled, #if the entire thing out and all imgui stuff too
    that way we don't have to worry about even supporting that on web for now

tiles window is broke rn because of move to simp
    should we fix it or just make a new custom tiles/entities window?

Maybe I should just git gud and make my own UI / custom version of getRect after all





## Monty On the Run ?

New goal is to make a basic ZX Spectrum / C64 style game with 
Need to keep as simple as possible so I actually finish it
like a tiny metroidvania precision platformer

if game is successful maybe we try to do a randomizer


### gameplay

player moves very similarly to Ash / OpenEnded
probably have ability to grab onto edges of tiles
probably not going to add hooks, just use empty tiles on wall

no tilemap rotations
    but we will need wrapping

basic platforming, maybe add new player abilities as the player explores
    if we do this, would like to make abilities relatively unique, but maybe all the basic things are fine too...
        ledge grab
        fast fall
        double jump (not sure about this, would almost certainly conflict with jump buffering)
        air dash
        swimming
        grab and carry things
            bombs? rocket jump?
            could allow for better secrets, more situational elements to exploit
        side flip
            e.g. donkey kong 94
        charge jump 
            e.g. mario 2
        
        change color of enemies to make them not hurt the player
        player can then pick them up and throw them around


player starts with 1 life, can expand lives permanently by collecting hearts
    works like tumors in Mount Moriah
    player always starts at very beginning of game on game over
    maybe do something like Artery for faster travel when the player gets good at the game or unlocks other upgrades
    player must hit a checkpoint in order to actually save any collectables
    
    
### other ideas

immediate-mode enemies and platforms
    e.g. fire bar, dynamically moving and resizing platforms

need to implement movement visualization elements, just attach them to anchor points on tilemaps or to entities

enemies that turn off and on like the big ghosts from tein
    reduce opacity while in this state

if we don't do tilemap rotations, we could potentially do multi-directional crusher tilemaps like in tein
but the collision detection on that would probably be a pain! (assuming we want it to be able to collide with other non-static layers)

if player collects a certain number of coins, they get a bonus "temporary life"
    could do red hearts / gray hearts type deal, gray hearts have to be recollected every run, red hearts are persistent

could do color tile type microrandomization in the future, would make the repeat playthroughs more fun


### screens / camera

    640x480 pixel screen, 16x16 tiles -> 40x30 tile screens


### graphics

    1 color per tile + transparency
    tile may have gradient
    so basically we just have grayscale graphics that we can colormod on a per-tile basis
    
    try to limit to 16 colors per screen? really fewer is better

    figure out how to determine colormod for tiles. Just use a palette index?








### time to rip and tear

Player:        
    remove all of the player powerup state stuff and use only a single player template
    try to clean up player physics struct too if possible
    change player hud (later)

    player dies in one hit, so we just need basic movement animations and death, which will probably just be a palette cycle

Tilemaps:
    simplify collision detection and rendering
    add spike collision type for tiles
    
    probabyl not actually worth it to strip out all teh rotation and scaling functionality,
    so instead we will just prevent it changing rotation and scaling in the editor and design other things around not being able to do that
    
    add tilemap wrapping within a frame
    allow separate frames for cutoff and wrapping so that we can wrap a large tilemap in a small frame
    

Enemies:
    removed shelled enemies
    add ability to refer to enemies by name in script so that we can script their movement
    
    all we need are:
        ability to hurt player
        ability to push player
        ability to be picked up by player
            cannot do if immediate-mode
        enemies have only a single animation ?
        or maybe we also want jumpy guys
        
        movement types:
            walk left/right
                maybe stay on platforms
            jump
                on player jump
                constantly
            float around
                follows walls
                follows scripted path
        
    
    add ability to do immediate-mode enemies simply by specifying template, position, and whatever else that enemy type needs
        problems:
            immediate-mode enemies cannot hold state (unless we feel like implementing that kind of nonsense)
            so basically they just have to be hurty or solid or platform hitboxes for player to interact with
                we can get velocity for these even if immeidate-mode by simply determining some instantaneous velocity (probably?)
                still need to iron out the kinks on that one
                    can maybe do some sort of unrolled for loop in scripts and static variables for saved enemy state
        



