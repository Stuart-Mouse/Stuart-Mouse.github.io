
# Level Ideas

first world is hodge podge of layouts lifted from smb1/smb2j/smb2u

level 1 is primarly 1-1 and 1-2 from smb1/2u
    will probably be primarily overworld / underground

level 2 will incorporate the vertical cloud section from smb2 1-1 and maybe even some kid icarus references
    more underground section with some moving platforms a la smb1 1-2 

level 3 will have mix of althletic overworld and castle
    castle will mostly be smb1-eseque, but maybe with some minor smb2 stuff
    

still not sure whether to use mostly smb2 enemies or smb1
    also not sure about powerup system
    will try to marry the powerup system of mario 1 with mario 2's pickup/throw gameplay
        but maybe this won't work out. in that case, something's gotta give...
        





# Random Ideas

cycling platform lift
    would be easier to use and modify than setting up a bunch of tile layers in script
    could easily control number of platforms and 2 main anchor points around which platforms move
    or create a polygon for path
    maybe some way to do this sort of immediate mode, like the fire bar?
    some option to control whether platforms loop or go one way
        need some nice animation for this case, dont want platforms to randomly appear/disappear probably
    could even control lift direction with lever

rope-like vines
    can have nodes be attached to different tile layers, or different points on same tile layer
        or maybe even to other entities?
    would provide something more dynamic for player to climb on than ladders
    fun callback to donkey kong jr
    
block that can eat the player, requiring another player to hit the block to get them out

add flag to entity to enclose it in a bubble
    then we can spawn bubble dudes out of pipes and stuff. could be fun.
    or maybe bubble should be its own entity and we add a mechanism to attach one entity to another?

adapt SNES versions of player sprites bakc into 8 bit versions, just to fix the small player sprites that look bad
    or, instead can use the mario maker versions of the sprites. unfortunately no peach, but maybe there's some fanmade spritesheet out there for that

make more use of the horns from wart boss room throughout the game as enemy spawners


mouse dudes who can stay in place on treadmills from mario 3d world
also mario-2 style castle levels with fun mechanical things
    conveyor belts, chain-lifted platforms, 
    section with rotating platform a la NSMB jungle level while beezos fly by, spawned from horns


could make items plucked from weeds work either as tile modifier or entity flag

would be nice to have some little scaling-up animation when enemies pop out of blocks



# Bugs

player/entity animation needs to consider gravity angle if it is animating based on player velocity
so we need to actually rotate velocity here as well, or we need to compute animation info in the update routine, which I'm not sure if I like...

unable to grab editor ui handles when they are overlapping

# Memory Leaks





# Overview of things needed for Wonky Kong

these are old notes but leaving here for now since I may want to implement some of these in this game as well

entities
    spawners
    from donkey kong
        barrels
        springs
            vertical and horizontal
        ladybug dudes
        maybe keep galoombas in, find different graphics though
        try putting in zelda links awakening goombas
    from mario bros arcade
        fireballs
        icicles
        crabs
        turtles
            maybe use beetles instead
    from super mario bros
        piranha plants
            and viney variant that grows across stage
            maybe hanging vine version?
            ptooie?
        the little walking muncher dudes?
            
    could bring in elements from yoshis island as well
        flowers that we can throw enemies into for extra points

spawners
    will be a bit more complicated than a regular entity, since presumably we will want to be able to define any of the parameters (or ranges for parameters) that are used to initialize an entity
    which will certainly result in an object that takes up much more space than any other entity type...
    so maybe we want spawners to be their own thing? stored separately from other entities






## plumber branch

now we're doing mario 2x2 
sort of a mix of mario 2 america and mario 2 japan

mostly mario 2 usa though

so we got mario goin

next we get the enemies mostly workign again


make a generalized check_flag() proc that is polymorphic on entity type, will check flags on base or derived object
e.g., can check entity_flags or enemy_flags


refactor player and enemy stuff more into base entity type
    or maybe make them both a common derived type from entity so that for the really simple entities we dont have quite so much unused junk
    
entity
    character (or actor or something)
        player
        enemy
    hazard (or something like that)
        fire bars
        platforms


    
    
## Physics

when a block is broken, it still takes some time for the collision to fully be removed, 
    this is intentional, but it is causing the player to not be able to jump up through a freshly broken tile
    I sorta hack fixed this, but then reverted it because it also caused a weird bug of its own, since I was just ignoring all collision points except D, DL, DR
    probably the solution is to have some velocity check, but not sure how to do this in a direction/gravity indepedent manner yet
    and no reason to do this now since we will want to refactor collision later anyhow

when entity has both left and right sides collides with same block, only recognize collision on the side that moves less distance to collide with the block
    currently, player gets stuck in block, as it tries to push player out in both directions
we have sort of a weird situation with collisions where we're doing this whole raycast thing, but it's sort of a werid discrete raycast
    that is, the raycast does not prevent the player or other entities from clipping through blocks as you may think it would
    that's because the raycast is sent from the player's center point out to each collision point
        (
            this really just solves a totally different problem than a standard raycast. 
            a standard raycast would be done in order to prevent teleporting over collision boundaries.
            the raycast we're doing here is done in order to prevent a problem that arises from doing axis-independent collision points
                if you just project out collision points which are not aligned to the tilemap's internal coordinate space, 
                we can skip over a small corner of a tile and instead index the next neighboring tile. This would almost be okay if all tiles had the same collision (entirely solid), but obviously this is not the case
                    and even then, indexing the wrong tile could mean getting pushed out in the wrong direction
        )
    maybe it would be worthwhile to do a new round of collision experimentation after we refactor tilemap collision
    could retry doing the sweep from previous collision point to new collision point
        problem though, is that we never know previous collision point
            so we would have to just approximate the previous point based on instantaneous velocity wrt tilemap
    

when releasing enemy from a block, make the position and angle on release match tile surface
add ability to hit entities out of other sides of blocks
visibly show entities inside a block when block is selected in details panel
    also highlight the block visibly in some way to show that it's selected


enemies need more probes so that they can be better aware fo their surrounding
    left and right probes should check if enemy is next to a small ledge they can jump over


applying some damping on the amount of velocity canceled seems to fix the issue where player loses all downwards velocity when walking down slope
    but this also breaks the ability for thrown enemies to bounce off the ground
depending on the collision response we want for a given point, we will need to parameterize the collision point accordingly

because of moving/rotating platforms, we definitely need to have very high friction applied when velocity relative to ground is near zero
but, this also makes it very difficult to accelerate up slopes
    so we need to also boost the player's acceleration when trying to move up a slope
    there's also a problem with how we cancel velocity when on a slope, since in order to get the nice effect when moving down of not cancelling all downwards velocity, then this also causes us to move more slowly up a slope
    


if entity is walking up a slope and slope is below some given angle (say 45 degrees), 
    then we should ignore the corner point and allow bottom point to hit the slope instead.
    this will look better and perhaps make movement slightly more consistent on some slopes



# Graphics

background tilemaps
    flag tilemap as bg so that we ignore all collision with it
    apply a color mod to entire tilemaps
    render a tilemap with a different shader effect
    maybe render with paralax scrolling or scale/skew enabled?


## Lighting

not even started




# Entities

spawners



## Enemies

Shells
    make shells react better to slopes, maybe slow down and even turn around 
    if shell hits a wall below a ceratin speed, the shell should just flip over, putting enemy into thrown state and taking it out of shell.
    then it must recover in the same way galoombas do to turn itself back over
    also, step the animation for shell spining and enemy walking based on movement speed like player, rather than basing it only on time


player gets too much vertical velocity when jumping from on top of a moving enemy/entity
    the amount of negative velocity imparted should match that of jumping from a moving platform

player also falls off moving entities

probably get rid of flipped flag in enemies and just use rotation
    this will probably fix the bug with koopas inm their shells being flipped wrong graphically
    also get rid of whatever hack I had for making shelled enemies turn off the thrown flag every frame


implement more mario 2 enemies
    Crabs for spiked enemy
    jumpy dudes
    pokeys
    
remove player ability to pick up spike ball
    add barrels or something for player to stand on instead
    
add entity coins into game
    fix particle not working
    
add entity spawning ability as just somethign that any enemy can do. 
    that way we will be able to implement things like lakitus and hammer dudes later on, or cannons with gravity and such
    
maybe we should just make items and other sorts of projectiles also be "enemies"
    



# Editor

reimplement flood fill, rectangle select, and copy/paste
either add in a real undo/redo system for editor or make it much easier/faster to save/load levels
    would be kind of interesting to do more of a branch-based system like git instead of just doing undo/redo

reimplement multi-select of tilemaps and entities

add ability to drop entities into block with grab tool


tilemap hovering and selection
    on hover and selection, decrease opacity of other tilemaps
    if in actual editting mode, then show tilemap bounds

rendering tilemap bounds
    instead of red/green bounds, would be nicer to have dotted/solid lines for bounds
        solid for actual capacity, dotted for current size
    
instead of placing entities iwth their own tool, I may instead just make the entity selector menu more like in mario maker, where you just drag the entities from the bar into the level
    but there are some things to figure out here...
    
tile layer movement visualizers
    no more movement components, so we will have to manually implement visualization functions that we can call on the individual components from script
    

## Level Timeline

would be nice to be able to set keyframes for a given tilemap at certain points in time
that way we can render a little shadow of the tilemap at that position in time even while we scrub along the timeline for everything else
    
movement visualizations
    start off with really basic dotted line visualization
    can either render path points or some component vector of movement
    could generate visualizer points based on distance, somehow

main question now is how to determine full cycle time of tilemap movement
    maybe for now we just have to be explicit about this
    otherwise we would need to analyze all expressions that are added to tilemap offset
        figure out where those expressions are periodic
            which will require metadata about the procedures or operators being called
            somehow relate all of those back to reliance on time
            except for those things which aren't based on time
                probably visualize those separately
                provide separate sliders for things like weighted platforms? or just show lines only for that?


    
    




# Audio / SFX

kirby adventure SFX has a lot of good stuff

options for enemies bouncing / landing on ground
    light   23 05 04 
    med     46 55 1c 17 02
    heavy   22 34 4c 4a 
    situational 43 57 41
    
    0e 0d landing, footsteps 
    
56 water ambience
48 water noise





some globals like entity templates, tilesets, and such will probably need to be moved into the GameState, EditorState, or runtime LevelData even.
    we will probably want to have different enemy templates and tilesets loaded on a per-level basis




# Overworld

Need to create an overworld framework which defines levels' metadata and connective tissue.
we may actually store things like level name, script path, and music here instead of in the level data structure, since that should only really concern the level layout
we may also use this as the place to define things like the tileset used for a level, bg art, etc.

we now have really basic doors that can instantly teleport play around and between levels
need to add some animations to make this look nice, some sort of screen wipe is probably fine for now


## Level Transitions

editor can use the same worldmap instance as is open in the gamestate
    but then editor_state has its ownactive layout
    we just move between layouts by right clicking on them or whatever

when we create a new layout or level in the editor, 
    the editor shoudl have its own buffers for entering some of the string info like music and script path
    maybe layout path can't be changed while we have a layout open, since that would be problematic


# Title Screen and other glue

not started




# Camera

make distinct icon for camera bounds handles in editor

# Console

maybe time to add a basic console in, so we can have better hotkeys for things like loading levels





# Gameplay

## Powerup System

Currently unsure whether to implement a powerup system or a health system more like in Mario 2
I will probably defer to the latter if I cannot find a way to make powerups work well with picking up and throwing things

Before doing full SMB3-style powerup system, maybe it would be wise to at least explore the Mario 2 mechanics a bit more first.
    - implement heart-container based health system from mario 2, including mushrooms that increase health.
    - implement Veggies and other ground-pluckable items.
        - Any entity type should be pluckable, ultimately
    - make spiny enemies damage player when standing on top.
    - make Barrel variant of spike ball enemy, spike ball should not be pickup-able
    - implement means for thrown enemies to hit other enemies


## Subspace

unlike original game, allow player to move around subspace and scroll the screen

I want to make a more interesting version of how subspace doors work in Mario 2
some examples could be warping the environment in other ways
    flip vertically, rotate everything, scale / skew even
    we can enable and disable certain transformation in the level scripts with a simple if check

nested subspaces
    hide subspace doors within further subspace, each time player nests into an additional subspace, time slows down further
    this gives player more time to find further doors

not sure entirely what the ultimate purpose of these subspaces will be
    may just use as a way to hide collectables








also remove default enemy phsyics
    or, maybe we create some default physics configu that gets loaded with global configuration, 
    so that we can at least use that as a reference in other data files
    
finish refactor of texture loading
    define file paths in globals file
    reload this data when we reload assets

put better tagged union in utils
    could we use this for Direction_Set enum?





malleable literals don't work with struct literals yet, but maybe we should consider using directives instead...
    maybe not if directives are too much work, but consider:
        could use directives like #slider() or #float() to spawn imgui menus or ui handles
            this has the benefit of being able to specify the proper transformations in some directive callback on serialization or what have you
            the directive can also modify the literals passed to it pretty trivially
            the main drawback is that we can't use an identifier to refer to some persistent malleable literal with this method
        really, we will probably need to marry the two approaches eventually
        
    maybe we should simplify struct literals to not be wrapped in a dot node
        or we just allow the dot node to function as the object of a macro binding if it is a dot-literal
        
    ok, made them work using the above method, but still need further testing to make sure this is right
    also need some means of setting the should_recalculate_tilemap_trails flag whenever a script variable is altered
        maybe this is where the directive part comes in, though we could also just add some mechanism to handle this in the existing script imgui window for "declarations"
    

figure out how to rename tile layer identifiers when tile layer is renamed
    how fully can we integrate scripts into levels to really make the whole level a sort of semantic construct?


need to better maintain player state between areas
    player states should probably go on some structure other than the level layout
    because the player is not really a part of the level, the player exists outside and across levels
    we just need to then figure out how we pass around the player data in conjunction with the level
    maybe it's fine if we just put the player data on the Game_State
    


fix entities in blocks, so that we can at least change entity type and basic properties in imgui
    use same menu for entity details and entities in block
    allow user to click on container tiles with grab tool
    implement custom ui for showing the entites in block visually
    allow user to drag entities into block with grab tool
        maybe even allow placing entity directly into block from brush tool

entity spawners
    should probably be a unique entity type and connect exemplar entity to spawn in a separate slot(s)
        the linking being a lot like how entities in blocks currently work, but without the need to put things on the level's event bus, since spawner entity can just manage it all
    want to be able to randomize arbitrary properties on the entities that get spawned, may even want to have some possible script integration?

basic main menu, level transitions, and game over screen

maybe a nice trippy shader for sky background

need to reimplement powerups, may just implement them as Enemy subtypes?
    no real reason not to do so, we can just easily flag the enmy template to give the player a powerup on contact instead of damagin player
        in that vein, need to improve overall player/entity interaction
        
also need to reimplement projectiles
    these will probably again be their own entity type, may just start by copying from old mario engine code



create a preload script that defines global variables that can be used in all other scripts
    need to figure out how these variables will be stored. maybe we just use a fixed buffer for that, or alloc a single block after evaluating script and we know how much space we need to copy the variables









    

## Modules Organization on Github

Modules TODO:

backup the sax file for gon module somewhere and forget about adding that feature anytime soon, not worth the effort

Make Data packer module dependency on Convert module optional
    remove dependency for File import, put that in examples folder or something
    probabyl remove or at least comment out unused local pointer stuff until I actaully decide to implement that fully
    
Make lead sheets work with C call procedures
    brainstorm ways to make context work better with LS, maybe script stores its own context pointer

Scanner 
    probably move the utils for lexing identifiers here as well
    move parse_number and string_to_u64 elsewhere (Convert.jai, probably)

Maybe create a version of DOM.jai that is slightly generic so that it can be used for both GON and LSD
    it's getting tedious to port all the minor improvements that are shared between the formats back and forth
    but maybe that's still the way to go if there's also enough distinct logic that we don't want to entangle
    will just have to evaluate this and see
    



In all files, split procs and data up into neater sections, improve readability

DOM.jai
    try to comment out as much stuff as possible
    change append_node procs to insert_node        
    get_node_index is probabyl kinda useless
        related to this, index refs were always kinda broken and still are in LSD, because they get lexical index instead of actual data binding array index, which is what we care about 99% of the time

Lexer.jai
    some common shared procs with LS, maybe clean these up and put in some lexer utils file
        Make a Scanner struct that just has file and source location, with some common lexing procs?
            issues around the particular semantics of each place where we want to call these lexing procs
            e.g.: lexing number requires that we are then able to properly parse that number later
            
            
Serialize.jai
    maybe also look for a module that handles utf8 stuff well. I am sure there's probably utf8 handling procs in the standard modules



Somewhat unrelated, 
    maybe we should also make an Any_Struct so that we can do a for_expansion on the members, similar to what we have with Any_Array
        that name is taken by preload.jai though, very unfortunately
        still, we can at least do a nice macro for it
        curious what other utility functions I could come up with for this...



Some pretty important things to clean up in data packer now due to the type info changes in last update
need a proper header for jai version info so that we can adapt type infos properly on load
need robust system for managing changes tot he basic type info structures across jai versions
need debug functionality to verify that type info structures are remapped properly 
need to use lookup table when remapping type info structures to prevent cycles and greatly reduce memory usage.
don't really need to worry about remapping trivial type infos like INTEGER, FLOAT, ENUM
don't really even need to store these type infos. (maybe that's where we finally use the local pointer stuff a bit and bring back the type info reduction stuff)



need header for all data blobs that we save

Blob_Header :: struct {
    header_version: int;
    jai_version:    Compiler.Version_Info;
}


still need to be able to load a blob headerless if need be

we don't technically need a header on any old data blob, since those just need the proper type info to parse it
but for the type ifo files, we definitely do need some means of telling how the type info is structured.
This leaves us with a really fun little bootstrapping problem




converting type infos between versions should probably be more custom than it currently is

ony call Convert utility functions shallowly, rewrite the remapping manually
    need to do this so that we can pass src jai version
        maybe we can pass the src jai verison in uer data pointer to remap callback



maybe we want to just have a single type_info structure that we always remap to/from and store type infos in that format
this coudl prevent some potential issue in the future and maybe reduce the size of serialized type info structures

we can use special local data pointers for the basic types so that we just never have to worry about those



Packed_Type_Info :: struct {
    version:        u64;
    type:           Packed_Type_Info_Tag;
    runtime_size:   s64;
}




Type_Info_Tag :: enum u32 {
    INTEGER              :: 0;
    FLOAT                :: 1;
    BOOL                 :: 2;
    STRING               :: 3;
    POINTER              :: 4;
    PROCEDURE            :: 5;
    VOID                 :: 6;
    STRUCT               :: 7;
    ARRAY                :: 8;
    OVERLOAD_SET         :: 9;
    ANY                  :: 10;
    ENUM                 :: 11;
    POLYMORPHIC_VARIABLE :: 12;
    TYPE                 :: 13;
    CODE                 :: 14;
    UNTYPED_LITERAL      :: 15;
    UNTYPED_ENUM         :: 16;

    VARIANT              :: 18;
}

type info tags for which structures actually exist
    primitives we can use local pointers for
      INTEGER;   
      FLOAT;     
      STRING;  
    
    almost primitive
      ENUM;      need names and values tables
    
    unsupported (no sense in storing these as other than `*void`, I think)
      PROCEDURE; 
    
    recusive ones (these can point to other tyoe infos, meaning we need to worry about that when remapping)
      POINTER;   
      ARRAY;     
      VARIANT;   
      STRUCT;    





This is probably sort of a noob question, but I'm running into a bit of a tricky (for a beginner) rendering situation. 
My game uses several dynamic tilemaps, and since each one of these can be quite large, I render each tilemap as its own batch. (So that I can just use a uniform transformation for all the tiles.)
All of the entities are then rendered in a single batch. (Since they all have their own position/rotation I just compute the vertices manually on the CPU.)
The problem is that I want to be able to render some entities between the tilemaps, and I can't do this while still rendering all the entities in one batch.
I've tried using a depth buffer so that I can render entities behind the tilemaps after

I've enabled a depth buffer so that I can render entities behind tilemaps, but of course this then has issues with transparency, meaning I would have to give up on having any kind of alpha on the tilemaps (which I don't want to do).


Render_Layer :: enum {
    BACKGROUND,
    
    TILEMAPS_BACK,
    PARTICLES_BACK,
    
    TILEMAPS_MID,
    ENTITIES_MID_BACK,
    PARTICLES_MID_BACK,
    PLAYER,
    ENTITIES_MID_FRONT,
    PARTICLES_MID_FRONT,
    
    TILEMAPS_FRONT,
    PARTICLES_FRONT,
}

Given the above set of layers, we would have to iterate over all tilemaps 3 times, entities twice, and particles a whopping 4 times
now, the particles can be easily separate out into separate emitters or layers with separate storage, so that's less of an issue
the entities though, that's a bit more difficult
    entities may want to move between render layers dynamically, or they may have some elements which want to render on different layers
    perhaps we would even want more entity layers, such as behind TILEMAPS_MID or in front of TILEMAPS_FRONT
    these would probably just be for certain decorative entities, but nonetheless, they would want to be on those layers

I could also easily see that we want to have certain particle emitters be between multiple tilemaps on TILEMAPS_MID
    and this case is not so trivial either. we could maybe iterate over particle emitters between each tilemap layer and check if they want to render before/after the layer in question
    
But this is all stupiud for the moment, and just a waste of time
I need to just make the game happen first...



# Particles

Currently we only have free-standing particles that all have individual lifetimes
these are necessary for things like breaking blocks and little damag eeffects, but are not ideal for groups of logically connected particles

free-standing particles can be spawned on one of four layers

we will also need to implement particles emitters which manage their own particles
these will have some enum to specify where they need to be rendered in the stack



just start building out some levels in order to figure out what we want to prioritize on the code / assets side








# Refactoring Entities

Things are messy right now so it feels like ti would be a good idea to do some cleanup before trying to implement new things.

One of the main problems is that the entity system is very mesy at the moment. 

## Some Notes

Warps don't really need almost anything that normal entities have.
    Although, we will want to have an entity for the potions that can spawn doors, so some entities will end up needing to contain warp info.
    These spawned warps are kinda specail though, in that many of their qualities will be auto-generated.
    
Fire bar is basically nothing like other entities.
    may as well be its own thing since it is so 
    
Enemies and the player actually share quite a bit in common (physics struct, 99% of collision)
    however, collision needs to be refactored to allow it to be more flexible, separate gathering of collsion data from handling of collision response.

Having projectiles be a type of enemy feels a bit wierd because they could easily be so much smaller in storage size,
    but we stick all entities in a unino anyhow, so not like it really matters atm
    unless at some point we decide to have separate entity storage for different entity types

Spawners are better off being a sort of component that can be enabled on another entity.

I think the direction for now will be to simultaneaoulsy reduce the numnber of entity types, while also separating entities into more separate structs
    Player, Enemies, and Items can probably become one generic entity type with distinct components
    (no ECS-like storage though, just all components present on every entity).
    entities will have:
        some main controller (player input or some COM function)
        some collision (against tilemaps, other entities)
        some physics
        some rendering / animation
        some spawner properties

    Merge items and enemies first, then maybe player
        player will be more problematic because player just has a lot more unique data and behavior
        
    But before even merging enemy and item entities, need to clean up enemies
    
    and before that, reorganize collision system a bit

Tileamp collision will be broken down into 2 parts:
    1. Get collision data for all collision points
    2. Handle the collision response for collision points
    
need to know velocity of entity in order to determine when we get a collision on certain collision points..
    maybe we should not require this? and instead onyl handle that in the collision response?

need better means for aggregating collision data across multiple tilemaps

for player, may be able to improve collision behavior by dynamically adjusting collision points 
    specifically, maybe we can adjust DL/DR feet points so that D point can better make contact with sloped ground
    or we extend some probe point down a bit further on D point to check if we are just above the ground, so that we can bring in our DR/DL points a bit or temporarily ignore them
    
    we will probably use other probes around player in the future to improve movement mecahnics
    can also provide better animation since we can detect when the player is close to hitting certain types of level geometry

create enum for player collision points which aligns with Direction enum
create enum for enemy  collision points which aligns with Direction enum

allow each tilemap collision point to define its own raycast start point 
    then we can more easily pass our other probing points for enemies and player
    
    
For debugging gameplay / collision stuff
    add manual camera control mode
        use mouse to pan and zoom camera during gameplay
    add ability to manually step the game update
    add better collision poijnts visualization



take notes on what things are messy or bad in enemy code right now
then take notes on what we would need to do to merge items with enemies

probably remove .FLIPPED flag and just use rotation
this maybe slightly awkward for spiky shell dudes,
but maybe we can just interpolate shelled dudes towards their nearest 180 whne held or grounded in case they are a bit off rotation
    could use .FLIPPED flag to indicate which orientation we want to interpolate towards
    use to determine target rotation, set based on current orientation when landing after being thrown


removed CRUSHED flag since we don't jump on enemies to kill them anymore
WINGED flag is also temporarily removed until we decide we want to implement it properly

reconsider if we even need the .MOVING flag for shells, since we may redo the physics to be a bit more dynamic,
allow shell to reverse direction or slow to a stop on slopes
    probably only on steep slopes
    shell should be able to accelerate itself a bit, though?

we should probably remove the `size` member from entity, and replace it with scale, so that we can just ignore it when it's not relevant
    do we even have any case where entities use size currently?

we should not need to pass render unit to any of our rendering functions
    this should either just be a global or should be part of the render batch transform

probably switch to tracking if enemy is grounded in the same way as the player


on entities and container tiles:
    the special case we currently have for coins will have to be some sort of special flag that we can just place on any entity type
    need to finish implementing timer-based multi-entities
        when timer runs out, play can still hit the block one more time
            

we currently have a bug with two moving shells that collide 
    both should die, but currently only one does
    this should be trivial to fix in theory but unfortunately the way we flag entities as dead is somewhat problematic at current
    we need some way to flag an entity that we want to actually mark as dead at end of frame
    also dead thrown entities should still be able to hit other entities as they fall offscreen
     




Friends Alt Version

meant for you long version
friends
wake the world
be here in the morning
be here in the morning darling
when a man needs a woman, extended cut with lyrics from alt version also
passing by (ideally with restored vocals)
anna lee the healer
little bird
be still (mix with alt?)
i went to sleep ?
busy doin nothin
I'm Confessin' / Cool as can be
transcendental meditation
diamond head


wild honey alt

with a little help from my friends
cant wait too long



# Porting things

make a list of things that we had to change in order for game to run on linux.
    change version number in vertex shader glsl code from 330 to 400
    disable gamepad stuff for now since it is crashing on linux

    for mooviz
        make a standardized version which plays nice on various platforms
        
    



