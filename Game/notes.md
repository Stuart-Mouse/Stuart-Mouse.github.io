
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
    we could either start player with just one life, or with 3
        starting with 1 would kinda be funny, but then we definitely need to give the player easy upgrades right off the bat
    maybe do something like Artery for faster travel when the player gets good at the game or unlocks other upgrades
        could be done with potion doors in the style of mario bros 2
        that way there is also some experimentation with finding the passageways
            doors out of subspace close behind the player, so choosing when to bail is extra important
            maybe lives cost more in subspace too, or something. will have to see if that's too hard. 
                or maybe player can only use grey hearts there
                and running out of those before getting back into normal space means game over
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


immediate-mode enemies that can toggle hitbox on/off has some really cool possibilities
    - fire bars that turn on/off by timer or based on buttons player hits
        - similar idea with fire bars, but changing direction on button press instead of which ones are live
        
could use numbered/lettered tiles to signify tiles that turn on/off with button presses
    then the buttons themselves can just be the number/letter itself, maybe in a little square or circle


### screens / camera

640x480 pixel screen, 16x16 tiles -> 40x30 tile screens
    need to leave room for ui though!
        maybe we just put UI on the side, since most screens are 16:9, not 4:3



### graphics

    1 color per tile + transparency
    tile may have gradient
    so basically we just have grayscale graphics that we can colormod on a per-tile basis
    
    try to limit to 16 colors per screen? really fewer is better

    figure out how to determine colormod for tiles. Just use a palette index?

    could change time lerp of color animation for tile on a per-vertex basis

    could use the grayscale value of color as a lerp applied to color animation keyframes
        won't be possible until we get back to shader stuff
    
    



### time to rip and tear

Player:        
    remove all of the player powerup state stuff and use only a single player template
    try to clean up player physics struct too if possible
    change player hud (later)

    player dies in one hit, so we just need basic movement animations and death, which will probably just be a palette cycle

Tilemaps:
    simplify collision detection and rendering
    add spike collision type for tiles
    
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


## Stuff to figure out

### Moving Between Rooms

We need to have some concept of seprate rooms that the player can move between.
    we should probably just start with a fixed room size and work from there
        that way we don't really have to worry about the camera for the time being
    in the future, I would like for some rooms to be taller/wider, probably still keeping to an overall map grid
        In theory, we could place all these rooms in one big map, 
        but in reality, we want to be able to individually reinitialize the currently loaded level layout very quickly and easily
        and this reloading becomes *very* nontrivial if we make these rooms on one big map
        so then the question is, how to make the transitions between rooms as seemless as possible
            but that is a question for later, I think



How to uniquely identify levels

for now, levels layouts are uniquely identified by a string.
It's a bit of a hack, but we will use any ID beginnig with "EDITOR" to refer to unsaved layouts open in the editor

maybe we can use some more general thing like ids beginning with `*` to indicate that the rest of the name follows some specialized structure
    we may want to also use reserved names for things like randomly generated or modified levels or something

we really need to just completely rewrite the logic for how warps work at this point, since they will need to just hold an id instead of level name

then wehen we do begin_level, we should jsut pass the ID
and the only failure condition should be locating and loading the level layout file
we should be able to play any layout without any additional level info, or without finding the loaded layout on the map.csv

also, we should probably remove Game.last_significant_warp and instead have some checkpoint construct that will allow us to recall any state we need to on player death
this checkpoint should probably be more than just a warp locator as well, since we could use multiple things to set a checkpoint location



TODO: actually implement some helpful console things
    also, make it where we have a separate console for the program and editor generally, and one that lets us execute things in the context of the level script
    even just being able to warp between levels or set game state variables would be handy



TODO: refactor scene transition event and warp event
    probably just use a single struct for this, use enums to specify what we do on fadeout, transition, and fadein
    


loading and saving levels in editor
menu bar will have dropdown menu for loading levels, scans the levels folder for content to populate list

when we start keeping multiple levels loaded at once, editor will need to keep track of what level is currently open, or if the level is unsaved
we should also add an editor hotkey to create a new empty level
    and/or add a 'new level' button in the main menu bar

Editor will directly modify level layouts that are loaded into memory, so we can iterate and play the level without saving to disk
    should later add some prompt for user to save unsaved levels when exiting the program

should have dropdown box to warp to any loaded levels, indlucing those that are unsaved editor levels


later, would be nice to have the ability to select a level by the map.csv
    also hotkeys for moving around map.csv in the editor


## Improving reliability of tilesets

Due to the need to be able to edit tilesets over time without making all our old levels unreadable, we need to have some sort of system for assigning a uuid or serial number to each unique tile in a tileset
Then when we save tilemaps, we will have to convert from tile indices to tile uuids

If we want to be able to automate the assigning of some persistent id to tiles that don't have one on load, we will need ot be able to save back over the tileset lsd file.
    so step 1 is check out lsd serialization and make sure we could write out a tileset file
        part of this will involve writing out any expressions used in the same way they were parsed
            we don't really have this yet in LSD files, per se
                will probably have to just hardcode some procedure for re-serializing tilesets
                
for now, will just have ot manually assign tile serial numbers, and be a bit more disciplined about keep track of these things

we also will want to have a nice gui tileset editor at some point, so this will also require writing tilesets to file, of course

serializing animations

intermediate step, just hand write a procedure to re-serialize tilesets
    we don't really use anything LSD-specific in loading these that one could not do with GON, so serializing tilesets back in a naive way should be fine

tiles are now being serialized with a proper 'persistent id' that can uniquely identify some tile over time, without relying on its order of appearance in a tileset lsd file
this is a step forward, but we also still need a lot of work to be done to implement a proper tileset editor and a nice way to sample from tilemaps

we will also have to think now about how to solve the issue that, since we are cacheing levels on load, 
    if we change our tilemap then we will have to reload the levels
    or at least remap all of the tiles before overwriting the active tileset that is currently in use.

Tilemaps no longer really need to have an anchor point, since the only transform we apply to them is translation.
    perhaps we should just remove this in order to simplify some of the code...

also, we should probably make tilesets use real clip rects, instead of indices that get automatically adjusted by the defined tile size

tilesets should also be able to define a lookup table with names for the tile groups within the tileset
that way we can use these names in the editor, and when defining the group id for each tile in the lsd file itself (using some custom lsd parse proc)


## Selection Tool

TBH selection tool should probably only be for editting tilemaps, and then we can just have a separate, similar selection tool that one can activate in the GRAB tool
the reason for this is that the selection tool will be most useful if it is separate from the brush, while a theoretical grab selection for entities would be most useful if it is just a simple modifier key
    
