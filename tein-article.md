
# Why The End is Nigh is the best precision platforming game ever made, and how it can be better.


## Overview

strong primitives lead to being able to do a lot with very little
overall structure naturally invites player into a deeper level of engagement
some techincal shortcomings limit the full power of the primitives
rushed development led to some interesting design avenues not being explored



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





