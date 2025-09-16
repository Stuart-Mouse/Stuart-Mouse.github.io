
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

Maybe I should just git gud and make my own UI / custom version of getRect after all

rewrite ui code stuff to generate a tree of ui handle nodes
that way we can track state for each one while still having immediate-mode interface




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

also, we should probably make tilesets use real clip rects, instead of indices that get automatically adjusted by the defined tile size

tilesets should also be able to define a lookup table with names for the tile groups within the tileset
that way we can use these names in the editor, and when defining the group id for each tile in the lsd file itself (using some custom lsd parse proc)


## Selection Tool

TBH selection tool should probably only be for editting tilemaps, and then we can just have a separate, similar selection tool that one can activate in the GRAB tool
the reason for this is that the selection tool will be most useful if it is separate from the brush, while a theoretical grab selection for entities would be most useful if it is just a simple modifier key




## Tilemap behavior refactoring

I would proabbyl not be impractical to refactor how tilemaps are updated, such that we no longer need to iterate over tiles in a tilemap to update them individually
Instead, we can use the event bus as a way of handling tile events, or just use some tile entity
we spawn the entity in place of the tile, let it do its thing, and then either return the tile or place another tile, etc.
in order to implement this, we will first need to implement the ability to attach entities to a tilemap
which should be relatively trivial now that we don't have rotations to concern ourselves with
    (we will want to somehow visually signify entity-tilemap attachment in the editor, though)

we will be able to slim down the tile struct as well, which should help quite a bit
    (maybe even remove the tile serial? not sure how much we really needed that in the first place, now that I think about it)
    won't need bump clock, crumble timer, and can remove some flags

I should have been smarter and realized I coiuld do this long ago
It's not even like I was unaware of this way of solving the problem, but I must have just had some prior reason why I thought it would not work for my use case


## other tilemap refactoring notes

Tilemaps no longer really need to have an anchor point, since the only transform we apply to them is translation.
    perhaps we should just remove this in order to simplify some of the code...
        trying to remove this atm is causing levels not to be able to load, and probably would also cause other issues
            perhaps we should do a cleanup pass later in which we also remove automatic resizing of tilemaps, since that should not really be necessary anymore...?
            then we could more easily just place tiles into tilemaps and not have to worry about our indices getting mixed up each time we place a tile
            we would also no longer need min index and max index, which would be nice!
            in retrospect, autommatic tilemap resizing adds a *ton* of complexity for, arguably, little benefit.


OK, so I removed the anchor point from tilemaps, and also removed size as a member as well
oh yeah, and velocity
this is because you can jsut derive both size and velocity from other variables that we actually need to track more authoritatively
so holding less state is just kinda nice and may prevent bugs if someone sets those variables wrongly (size and velocity were essentially readonly outside of single functions)

Still on the docket is fixing and simplifying the code for placing tiles and resizing tilemaps
simplifying the existing logic will probably be enough of an improvement, but potentially we could further improve it so that there's a sort of shared overall capacity between the x and y axes of the tilemap
how useful is that though, actually?
and the existing code works fine, so just simplifying a little bit is probably sufficient

if we WERE to go through with chaning the manner in which tilemaps resize further, we may want to just store a stride instead of storing size as x/y pair
    this does mean we would have to calculate the height of a tilemap from count / stride, but maybe that's just fine? idk man




## Organizing / Clean up Pass

need to reorganize a lot of game assets in centralized places like I have it in the fire rescue game
no reason we should still have random textures just declared all over the place...

we may also want to make certain systems more independent from the global game/editor state
tilemaps need this wrt editor and context variables, for sure

reorganize game update/render loops so that we can just do a straightforward update/render when aiming for a fixed framerate


### TODO

Organize resources:
    simplify audio loading
    
    
Interfaces / modularizing
    tilemaps?
    move vector/rect stuff to utils module?

DONE: Make IO Data work for polymorphic structs
probably also write some remapping helpers for static string and fixed array


need to implement serialization for implicit derefence on struct member access

attach entity to entity

tile entity collision

add big fireball entity
    also change existing fireball graphics
    
implement tempo control on entities and level

implement another way to move tilemaps in editor
    when editing tilemap, just hold alt to reposition or something
        maybe even remove the handles after that, idk
            maybe we don't need the anchor point after all....
                though maybe it will still also be better to keep around for the sake of consistently indexing tiles when we restore saved level state
                    but in this case we should make the anchor point an integer index
        if we keep editor handles for tilemaps, should make hovering the handle show the tilemap bounds, or otherwise highlight the tilemap

create some procedure for rendering platform entities and other decor items of unusual dimensions





### Rendering Notes

I got the idea to blend the color palettes between bordering tiles, so that we can have colors smoothly change between adjacent tiles with different palettes
this is going to be more difficult than I initially imagined though
the main issue is that we really onyl want to apply this kind of color blending in very specific situations, and which vertices we want to apply it to will depend on the tile(s) in question
for instance, we want any 'outside' surfaces of ground tiles to be hard edges, not blending their color with other adjacent hard edges
    (even this situation is more complex than that, because we may want to blend with one neighboring tile but not another...)
    
this blending would not even be so necessary if it weren't for the fact that we are giving most of our tiles a sort of dark backdrop color in addition to the bright color they primarily express
    this is what makes it problematic to put two tiles with different palettes next to each other...
    so perhaps we also just try removing the use of this bg color one again and settle for having only a single background color

If we do want to try and have our cake and eat it too later on, the approach will probably require storing some precomputed/cached array of what all the vertex colors's palletes should be and weights for each palette
    then we compute the color at each point for each palette and averge them based on the weights
    this is all very expensive per pixel, at least for a simple 2d platformer game!
        and the (over)use of transcendental functions does not help


### Implementing Checkpoints

create graphics for checkpoint

implement animation states for inactive/active that we can use for checkpoint
    or otherwise animate differently when it is the active checkpoint

deposit temp hearts at checkpoints?
    can be redeemed on another run at the same checkpoint

remove checkpoint on game over

store other saved state on checkpoint activated
    probably create a helper function to set checkpoint just taking the warp locator

only commit collected hearts after hitting a checkpoint
    heart follows player around until reaching checkpoint





