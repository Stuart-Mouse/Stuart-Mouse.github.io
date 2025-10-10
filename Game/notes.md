
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


## Random Ideas

will probably have to save most or all of these ideas for a later game, maybe Gourdian?

Items for player to collect over the game: 
    watering can
        allows player to get different liquids, pour them on things
            some liquids can be used like portal's gels to modify tiles or entitiess collision properties
            e.g.: water, slippery gel, tar, gasoline, lava
    spade
        allows player to dig things up out of certain types of ground, maybe even poke enemies?
    gardening gloves
        allow player to pick things up and carry them around
    music box
        allows player to somewhat control the tempo of levels (or elements of level), slowing them down or speeding them up
            maybe different songs have different effects, have to be unlocked separately

at some point, player could use spade or gardining gloves to dig up checkpoint flags and move them around
    this could be required for late-game areas or for navigating subspace

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


Interfaces / modularizing
    tilemaps?
    move vector/rect stuff to utils module?
    simple animator can be its own module, probably
        or at least be moved into utils
    look over utility.jai and maybe move stuff elsewhere

Consider breaking Utils module into separate modules
    will require setting up a new directory for my own modules, separate from main jai/modules folder
    

Use simple animator for ui handles' clips


Create persistent IDs for other resources:
    tilesets        - just use a static string
    color palettes  - uuid or short string?
    
    

DONE: Make IO Data work for polymorphic structs
DONE: probably also write some remapping helpers for static string and fixed array


need to implement serialization for implicit derefence on struct member access
    probably already works actually, but need to test



## Various TODO Items

tile entity collision

add big fireball entity
    also change existing fireball graphics
    
switches/levers
    will use some Static_String ID to identify 
    player can interact using some button
    can switch entities  and tiles between inactive/active state
    entities and tiles define what group they belong to via this id
        should also be definable at the level of entity group instead of individual entity

create some level_with_info struct similar to Game.active_level's contents and use this in place of context.current_level
    so we can say, context.level.layout or context.level.info, etc

make convenience functions to create and append Render_Commands to a given array.

world_to_screen functions in context?
    could add such function pointers to the simp renderer context so that game/editor can push these useful functions at beginning of update routine
    or maybe these transformations should just be set in the general render transform... (probably this)

## Editor UI Refactoring

firstly, multi-select
    cannot work if we use a hot/active ptr in ui_state
        need to make the hot/active flags on nodes actually functionally valid
    cannot work for positioning multiple things if we use mouse position rather than some mouse delta
        which means we need mouse velocity to be reliable for this use case
        maybe we should reconsider using some ui_action struct for handles to handle rather than requiring them to check mouse state manually...
    
    may need to use entirely separate mechanism for multi-selection than standard hot/active
        need to specify whether a handle should be selectable using multi-select, since for many this would not make sense
        also, many elements may not make sense to have certain actions enabled when multi-selected
            e.g. right click functionality or click with modifier key (ctrl/shift/alt)
            
    we could implement multi-select as entirely separate from the rest of the ui selection state
        then just communicate back to the ui node that it ought to display as if it were active/selected
            
        this may make the most sense anyhow, since I really only see myself using the multi-select for top-level things like entities' and tilemaps' positions

moving multi-select into ui proper
    each ndoe can have some arbitrary class id assigned
    then we can set the mouse selection class to make sure that only things within thedesired class get selected when multi-select is active
    the actual state determining whether some node is marked as selected will still need ot be held by user
    they will provide that state just like the provide the 'hovered' flag to update_active_hot_state
    ui will return some result flags tell the user if we set the hot or active node to the current node
    and the user should handle those in whatever way they see fit

determining render color for some node
    utlimately this is up to user, but the default method should be better here
    base_color, hot_color, active_color need to go in ui state, not as parameter (except mayube as optional param, and then we should havesome ui style struct)


## Immediate-mode entities

start with most simple entities
maybe just a do_immediate_entity proc that takes an entity template id and optional parameters
    will not hold any entity state, just puts the entity in given location with given parameters, does collision and rendering
        animations could potentially be of some concern?
    this will work for the very simple cases like fireballs, but even platforms will require knowing previous state

Maybe we should outline the teirs of immediate-modeness of entities and what their implementation will require

1. completely immediate
    e.g. fireball
    given location, template id (for rendering and hitbox size)
    can only be simple damaging collision type

2. immediate + velocity
    e.g. platform
    same as above but we will also need some previous/next position provided in order to compute instantaneous velocity

3. all state retained
    requires actually creating an entity in entities array
    can have complex collision or other state
    will require some "comptime" features (directives) in scripts





## Special Entity rendering

for platform entites and other things which need to render special things like supports
we will need to improve how entities are rendered, animations, etc

should be able to define default animation state for an entity template

define animation states such as IDLE/DEFAULT, BOOKEND, SUPPORT, WIRE
    which correspond to parts of platform

then we can also probably just have some rendering mode enum to dictate how we animate and what aniamtions get used how


support_self_attachment_offset
support_target_attachment_type
support_target_attachment_handle
support_target_attachment_offset




## copying static variables from one script to another

This problem is actaully a bit tricky because if we want to preserve static variables we will have to either:
    1. write a procedure to copy an entire sub-tree of the AST from one script to another
    2. write a procedure to navigate scripts and find variable declarations that correspond from one script to another
        This approach seems lamost entirely unworkable unless we just blindly assume both trees already have the exact same structure
        which we may not be able to do if we introduce some randomization at the AST level through directives or whatnot


so it seems the only real solution will be to copy all nodes from one tree to another
problems with this approach:
    - also need to copy all strings, or script source in its entirety
        - maybe don't need to do this in my specific case since we can presume everything is already typechecked/resolved at level runtime
    - adds another requirement for user extensions to implement a copy_node callback (and maybe also complicates directives?)
    
If we implement lowering to bytecode and just use that when playing a level, then this entire problem disappears since we don't even need the AST anymore. 
we can just point at the bytecode buffer for a script the level layout doesn't own (owned by loaded levels cache) and we are hunky dorey


Another solution would just be to mark in the active_level that it does not own the script its pointing to, or to make this an assumption across the board.
but this would also require a lot of refactoring and would complicate a lot of things

another solution is to just serialize the ast from the editor with the modified statics and use that as the source for the loaded level script...
    maybe this will be the most simple for now?
    before we do this, we need to jsut test serializing scripts back to source again and make sure it is relatively robust, works with all current features
    also, add an option to not serialize comments and whitespace back into output. no reason to do so if we are just using the source as an intermediate




## Movement visualizations

First and easiest will be to simply draw a dotted line between one point and another, with a given number of dots
this can be done from scripts in immediate mode way

after we do it with simple untextured quads then we can do a version with texture
then we can start thinking about other types of movement visualizations

should render all movement visualizers before rendering entities themselves





## Physics 

Player and entity physics should be more runtime-adjustable/modifiable
we should create separate members in the physics struct for the framerate-adjusted values, leaving the raw values intact
that way we can adjust the physics automatically if the game switches monitors or we detect a new framerate
    (will need other logic to automatically detect framerate)
In addition, this change will allow us to change physics values in some IMGUI panel in realtime and recompute any framerate-dependent things as needed

## Other windows / modes

In addition to the game and editor windows/modes we should have distinct modes or update/render routines for a tilemap editor, tileset editor, and other such utilities
Ultimately, It would be nice if we could actually create additional windows so that we can pop out these views into separate windows




## Entity Groups

Currently, entity groups are just indices and an associated name that is only for display purposes.
They're just a basic organizational tool, primarily so that we can refer to groups from within scripts.
In the future we may find it useful to attach some additional information to each group, such as:
    tempo override / scalar
    palette override / scalar
    override other entity template values on group as a whole ?


Could restrict absolute max number of entity groups to 64, then use a u64 as a bitmask for group membership
    (I don't think I would ever need more than 64 groups, or even probably more than like eight tbh)
that way we could make entities be members of multipel groups simultaneously, which could be interesting
we could also toggle group membership as part of init block randomizations so that entities may only optionally get certain properties applied


