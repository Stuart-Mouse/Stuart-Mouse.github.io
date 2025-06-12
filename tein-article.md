
# Why The End is Nigh is the best precision platforming game ever made, and how it can be better.


## Overview

strong primitives lead to being able to do a lot with very little
overall structure naturally invites player into a deeper level of engagement
some techincal shortcomings limit the full power of the primitives
rushed development led to some interesting design avenues not being explored


player movement
    enhanced vertical movement
    the wooshie
visuals that complement gameplay
    use of color, silhouette
    player trail to sell the movement
level design
    more dynamic layouts with movement tags
    enemy designs




## Very strong primitives

nigh perfect control over player movement
    fastfall is a stroke of genius when you fully appreciate what it does for movement
        brings more parity between horizontal and vertical control of the player
    hooks > wall jumps
        shift more power to the designer
        great way of communicating intent, can be used as a subtle hint
        also complements collapsing movement very well
        wooshie jumps allow player to initiate a more horizontal jump
            again creating more parity between the horizontal and the vertical
            but also, since it is contextual it is constrained
            pairs with breakable blocks in a very cool way that shifts the player's attention
        
    tein is slower than super meat boy
    
    movement is very tactile
        shifts back and forth between being smooth and very stacatto
            hard to convey exactly what I mean here, but if you've played the game you may immediately know what I mean
            the optimal way for the player to climbs walls is by alternating between jumping and fastfalling in a very rhythmic way
            and then when you perform a long jump, there's this immediate contrast of smoothly sailing through the air
        the player has this trail that just makes all movements feel like they flow
            
    
great selection of enemies
    in general, many are just dressed-up spikes
    but, some are walking/floating springs
    and some are simply moving platforms that have a bit of reactivity (thwomps)
        the fact that the thwomp-like movement can be applied to any arrangement of tiles is also really cool, as it adds a whole new layer of composition that can be used to design levels
    
    I think this simple approach of just 'dressing up' the existing primitives of ground, spikes, and springs
        is really a great way to make certain applications of those primitives more intuitive
    of course, it's also good to have entities that actually add new behaviors or mechanics to the mix, 
        but the most versatile entities are those which just tap into the game's primitives and re-present them in a way the player can better understand
    the additional behavior that an entity adds on top of the primitive can then deepen the space of possible interaction further,
        rather than simply tacking on some novel, but shallow interaction
    
    croasts and frogs are the weakest, but they sort of work for what they are
        more unpredictable, force the player to be more reactive
        but also highly constrain possible design space
    comparable use cases to n++, interestingly enough

    gas clouds and poison water can be used to create natural time constraints in level design
        also serve as a way of partitioning space
        the best uses force the player to approach the same underlying level geometry in a different way 
        
        gaspers are a composite of hoasts and gas clouds
        poison water is a composite of water and gas clouds
        

    machine guns can enforce a sort of spiral movment
        environment can then be used to change direction of spiral
    laser eye dudes are somewhat similar, but more based on a time constraint. 
        forces player to think about how to position oneself such that they are never in a clear line of sight
        

## Forms of Tilemap Movement

The more dynamic levels are somewhat necessitated by the choice to limit all levels to only one screen.



### In-Game Progression

World 1 
    collapsing motion
World 2 
    cyclical movement for floating platforms, mostly just up/down and left/right
    also introduces large screens with cycling enemy patterns (kukos blowing in the wind like tumbleweed)
World 3
    applies movement tags to gaspers
World 4a
    major pieces of wall moving in cycles to push player down
    rising movement tags are a nice inversion on the collapsing movement
World 5a
    
World 4b
    weighted motion (clouds)
    more use of collapsing motion
        complemented by mother
    much more complex movement patterns, major sections of level use wrapping motion
    mother creates very responsive/dynamic levle geometry (extension of spikes)
World 5b
    direct use of moving spikes
    introduces smashing movement tags
    introduces conveyor belts 
        conveyor belts are very interesting in this game, on walls they behave sort of like moving hooks
        gives the player a new way to scale vertical surfaces
    combines conveyors with moving platforms for interesting results
    introduces gravity beams
    between conveyor walls and gravity beams, this area actually introduces some of the most interesting solutions to the verticality problem
    brings back gaspers with more movement
    disappearing/reappearing tiles are applied in the same way as movement tags, so they are also applicable to any tile type
    
    
World 4c
    movment tags on floasts and water
    introduces hoasts, rotator guys, breakable blocks
    
    
World 5c
    subtle up/down movement on lava, creates these crunching sections with low ceiling
    sharp up and down motion of spikes as they protrude from and retract into the ground
    multi-directional crushing motion can almot be used to create simple puzzles
        in conjunction with breakable blocks, the player has to guide this moving piece of level geometry into place
        
        
The final Future (steven) level really gets crazy with the wrapping movement and I think it's one of the coolest areas in the game. 


### How tilemap movement creates more dynamic gameplay

the player can effect meaningful changes in a level's layout by grabbing onto hooks and pulling down parts of the level geometry

buttons can be used to toggle movement of platforms, or turn the tiles themselves on and off




## Overall structure

continuity of levels provides a much better feeling of place than super meat boy
    however there's less feeling of development between levels in the same area
        partly a byproduct of the game being monochromatic
        but also there's just a slower pace of ideas being thrown at the player

carts have multiple purposes
    provide a more substantial collectable than tumors
    ease the player into the idea of having lives before the dark world hits
    give the player some way to practice and make progress even if they get stuck in another part of the game
        the split also serves this purpose

there's a shift in gameplay style from just beating individual levels to requiring longer periods of consistent performance
    this happens very smoothly through the combination of several game mechanics
    
and the final moments of the game 
    ruin escape sequence is a great way to end the game without trying to shoehorn in some kind of boss fight
        imposes a pretty tight time restriction on top of the player's already difficult situation
        conveys the game's theme of being in an increasingly stressful situation
    nevermore is just an extreme restatement of the dark world, giving the player very few lives to complete the final challenge
    
carts actually have some of th emost pure gameplay in the sense that their designs are based almost soleley on moving platforms and spikes, and some basic enemies



## Technical shortcomings

underbaked level file format
    groups of moving tiles must be connected by movement tags
        movement tags also constrain the variety of movement possible
        hard to control how elements wrap around the screen
        hard to coordinate foreground and background layers' movement
    hard to create certain forms of level geometry because we only have one active layer to work with

to be fair, the game was made in (iirc) only 8 months
    so I can understand why the level editor is so basic and (imo) underpowered




## Design shortcomings

level design does not lean into the movement tags enough in my opinion, it still leaves a lot on the table
    no real use of highly synchronized movement, closest we get is some very cool uses of sine-wave tags in one of the vertical wrapping sections
    no real use interplay of wooshies and water
    no use of moving hooks
    limited use of rising movement tags
    limited use of level wrap
    swimming mechanics, while solid, lack much depth
        use of underwater mines or currents could have allowed for more interesting underwater sections
    
there's actually very little use of wooshie-preservation techniques in the base game
    this is really something that's been explored thoroughly by modders
    but tbh, there's not too much depth to probe since the game is just missing some of the essential primitives that would be required to make momentum play more interesting
    not to mention the game's insanely high air friction, which makes stopping and starting wooshies a bit of a weird quirk more than a real mechanic

limiting level layouts to a single screen can be a bit *too* limiting
    especially limiting on verticality


## Building on the game's design

use of momentum
    wooshies are one of the game's most distinctive aspects
    
more complex level geometry
    the idea of the fastfall is complemented very well by slopes
    slopes allow the player to redirect their momentum, turning vertical speed into horizontal speed

better designer control over timing and motion
    (platform needs to be in specific place at specific time in order to coordinate with other elements of level)




### Weak vs Strong use of certain design elements

many of the mechanics in tein are used both for very interesting and also less interesting applications
this is very vague, so let me be more specific
some elements such as moving platforms, gas clouds, mother all serve the purpose of applying some constraint on the player's movement, often a timing constraint
the weak version of such a mechanic is something like what is most often seen with the gas clouds, where the player just needs to navigate the same obstacles in the same way they usually would, but *faster*
this makes the level hard, sorta, but it doesnt make the level more intersting
a better applicaiton of the mechanic would use the specific layout of the gas clouds to force the player into taking a different path through the level, or at least to add some additional articulations to the player's movement 
    e.g. 1: short path and longer path, player is forced to take the long path because of clouds, 
        added bonus: shorter path becomes available later due to turning on conveyor belt, meaning player can now get through faster (tumor path?)
    e.g. 2: player has to make lower or higher jumps based on cloud coverage, bob left/right to get out of clouds while climbing
    
#### Soft Constraints

Clouds and Mother make for rather loose constraints in many cases since there must always be some level of leniency within such a time constraint
    the best level designs will factor in this leniency in such a way that the player is given real options about how to navigate the level
    e.g.: the player can reach one of two different "safe points" outside of gas clouds, one of which requires using a ledge jump in order to gain additional speed

Building on prior point, these soft constraints or "pressure" elements in a design can be played off one another to create more interesting scenarios
    For example, in Retrograde, we have the falling platforms which provide a sort of "waiting" constraint, while the Mother on the ground and lower falling platforms provide a "hurry up" and "move now" pressure
    This makes the player take a step back, consider the level as a whole.
    now the player must figure out how to reuse the space they are in for long enough to stall for the collapsing building, without crossing themselves
        The retrograde example is really sort of a restatement of a similar idea we see in The End, thought that level is more simple, using only crumbling tiles
        It's the same idea in both cases, but in Retrograde it's a bit more obscured by the fact that the Mother is easier to run headlong into without considering the consequences, so there's a bit more suprise when the player gets himself stuck.
            it creeps up on you... literally
    retrograde also does more of this in one of the secret areas
    
so, while sometimes it's all well and good to use gas clouds or Mother as a simple "do it faster" mechanism, it actually creates more intersting levels when you can use the same mechanics to make the player slow down, rethink their approach, or at least navigate with a bit more finesse

#### Importance of Context

Another thing to consider about moving platforms is that, in some cases, the actual movement may be mostly irrelevant to how the player navigates the level
for example, in The End, we have one level with a giant collapsing building the player must climb down.
but if you really stop and think about it, there's almost no difference in wha thte player actually has to do here if we just place an explicit timer on the player to navigate the structure
There's maybe a very minor effect on the player's jumps due to the movment of the structure, but still, minimal effect here
that's because there's nothing else in the level that's not moving within the same frame of reference.
we can get a much more interesting level simply by adding some elements which aren't part of the same collapsing structure or collapse at a different rate





# Super Meat Boy

Level geometry is almost entirely static, the only exception being if you count the moving platforms as part of the level geometry (which i don't really think you should)

The game is more about getting the player to understand and really internalize the movement options provided to them, and then 
The player moves so quickly that if the level were also moving at any sort of speed, it would just be too hard to land certain types of jumps

There is certainly a level of articulation lost in the player movement in tein as compared to super meat boy, at least in the x axis
Ash actually has more control in the Y axis due to his fastfall, which I think goes a long way in making him capable of a higher levle of responsiveness to the more dynamic levels in the end is nigh


With ash, there's much less of a learning curve to simply controlling him, but the 

Super meat boy stays fresh by adding in new enemies/entities with unique behavior and interactions

You can really see the difference between the two games in their endgame level design
the cartridges in tein use more complex movement tags and fewer / more simple enemies
cotton alley turns into an onslaught of very tight jumps and timed arena rooms that just challenge the plaer to survive a stupid amount of highly random enemies

SMB moves towards its more idiosyncratic elements while tein leans into more highly patterned designs




# Super Lumi Live

## Disclaimer

I have not actually played the game, but I've watched a few speedruns that 100% it, so I'm pretty familiar with the game's content.



### Density of Ideas

The game seems to have a relatively high density of new ideas and mechanics, with each level bringing something new to the table.

However, the overall level design seems to be a bit weak, with some obstacles being very incidental.
There does not seem to be a real strong flow between ideas in level layout.

So while there are some interesting mechanics and concepts, the final execution is left a bit wanting.

The game also seems a bit short, and that being the case, there's even less room to have layouts that are weak in conveying the interesting parts of the game's mechanics.








# Other design ideas

## Understanding vs Articulation

distinguish knowledge from understanding
    one can obviously know the solution to a puzzle without understanding how that solution is derived

distinguish execution from articulation
    I am not sure I have this figured out as much, myself...
    "The art remains with the artist"
    execution is more like, having done something successfully
    articulation is moreso the ability to execute consistently, having ht emsucle memory or some embodied form of understanding
    
A major part of amking a puzzle game good is fostering understanding instead of just simply requiring the proper knowledge
get the player to think systematically, derive solutions from first principles.

likewise for an action game, the player should build up an intuition for how to approach certain gameplay scenarios


puzzle games generally try not to require much in the way of articulation, as this can distract from the emphasis on understanding the ideas behind the puzzles

for action games, one may be tempted to think that the opposite is true, that focus too much on understanding complex systems 
but I don't think that is straightforwardly true
in an action game, it smuch easier to have sections that require very little in terms of mental understanding but are still fun and engaging. assuming that the basic dynamics of the game are fun, moving feels good and whatnot

the game can force a certain type of articulation by also requiring some understanding on the part of the player

articulation is cultivated in response to some new understanding
player learns how to take the proper stance towards a novel situation

related to how very experienced players can "read" a kaizo mario level
has something to do with the common conventions or flow that the genre has established
but this also clearly demonstrates that some hihg-level understanding is present, not just an abiltiy to articulate



where do you want to spend your complexity budget? having more modes of interaction, or making a single mode of interaction very deep?

in that way, I think puzzles games tend to be more pointed in their design, but this is not to say that action games cannot have extremely nuanced design as well
it's just more about suggesting to the player what they should or can do


tldr
puzzle games sacrifice articulation for a greater depth of understanding
the genre of an action game makes accomplishing the same depth of understanding more difficult, 
    also requires a different tpye of understanding which I think is a bit more embodied and intuitive,
    rather than one which is based purely logical
having a proper understanding of the mechanics in a platformer is critical to making fun levels though
because this understanding gives a designer the ability to finely tune the articulation that is being asked of the player
the designer can then use the player's intuition to guide them into the proper execution, or ot subvert their expectations and trap the player
    which is ultimately also a form of guiding the player, if the trap is explicitly a rebuke o fthe players actions and not too subtle




## Platformers that make good use of movement

the end is nigh
super lumi live
new super mario bros u / luigi u
    it's a shame that the physics in nslu suck, because the level design is much more interesting than any other game in the nsmb series
    to me, it actually feels like more of a natural evolution of the smb3 level design than the more smw-like design which predominated most of the nsmb series
    maybe just due to the shorter and more focused levels and lack of checkpoints

super mario bros wonder
    wonder buds make levels even more dynamic
        sometimes used in somewhat similar ways to tein's buttons

slu has a lot of dynamic movement in its level geometry
    primarily based on global cycles and invisible trigger volumes
    even trivial things which really don't need to be moving have some subtle motion simply for the aesthetic appeal, makes the levels feel more alive and bolsters the feeling of needing to stay on one's toes
mario wonder on the other hand, does not have a whole lot of dynamic movment to its level geometry during normal gameplay (some wonder effects to do however)
    but in most cases the more dynamic elements are special entities
    most of the dynamic interactions are driven player interaction with wonder buds and pull-chains
    I really like both of these elements, the wonder buds are very digital, while the pull chains are very analog
        so they serve distinct purposes in the level design
    the pull chains are like an even more dynamic version of the spinning peg things used in nsmbu, which are sort of analog but not really, since you almost alway sneed to just throw them all the way open and thne finish the subsequent timed challenge
    the pull chains give the player more direct control and also make the player consider where they can move while pulling the chain, which is a lot more interesting

while there is a time and place for simple trigger-based dynamic elements and levels, the more that you can communicate the dynamic change before it happens, the better (in most cases, of course. there are also times you want to surprise the player with something totally unexpected)
tein's buttons and the wonder buds are a great way of doing that communication, with different levels of explicitness





# articles/videos to make

The end is nigh and why it's great
    strong primitives and composabable mechanics
    
primitive vs deorative mechanics and arrangements vs compositions
    
ideas about randomly generated content for precision platformers

how modern audiences misunderstand Mario 1 (probably a smaller video)
    
the witness as understood through the incarnation





platformers all share some fundamental constraints
gravity provides your main constraint on the Y axis

there's an often-retold story about mario 64's design process:
    the designers wanted Mario to be fun to move around in an empty room
        this is often a good starting point, but I think I actually prefer a more limited moveset in many cases, since it allows the level design more room to show off
        I prefer designs where the player can demonstrate mastery through the interactions between a more limited moveset and the environment itself
        rather than giving the player some way to get aroudn the "intended" path, the design should account for all the various ways in which the player may move through the space, and facilitate both low and high-level play
        The more the high-level routing can be hidden in plain sight or worked into the standard route, the better
        The hand of the designer should be very subtle here, allowing the player to feel as if he's simply discovered the ideal route himself






