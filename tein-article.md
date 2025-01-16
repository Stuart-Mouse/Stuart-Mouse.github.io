
# Why The End is Nigh is the best precision platforming game ever made, and how it can be better.


## Overview

strong primitives





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
    
great selection of enemies
    in general, many are just dressed-up spikes
    but, some are walking/floating springs
    and some are simply moving platforms that have a bit of reactivity (thwomps)
        the fact that the thwomp-like movement can be applied to any arrangement of tiles is also really cool, as it adds a whole new layer of composition that can be used to design levels
    croasts and frogs are the weakest, but they sort of work for what they are
        more unpredictable, force the player to be more reactive
        but also highly constrain possible design space
    comparable use cases to n++, interestingly enough

    gas clouds and poison water can be used to create natural time constraints in level design
        also serve as a way of partitioning space
        the best uses force the player to approach the same underlying level geometry in a different way 


## Overall structure

continuity of levels provides a much better feeling of place than super meat boy
    however there's less feeling of development between levels in the same area
        partly a byproduct of the game being monochromatic
        but also 



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




## Building on the game's design

use of momentum
    wooshies are one of the game's most distinctive aspects
    
more complex level geometry
    the idea of the fastfall is complemented very well by slopes
    slopes allow the player to redirect their momentum, turning vertical speed into horizontal speed

better designer control over timing and motion
    (platform needs to be in specific place at specific time in order to coordinate with other elements of level)





