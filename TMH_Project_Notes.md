

## Ideas

Fish pond, where you can feed the fish

## First demo

TV with various channels
unused channels will show some static
can easily add new channels over time
channels could have interactivity or just show visuals/sounds
    interactivity could have conditions that link user to other pages
    
    
    
image of tv is static image or a few frames for flickering light or soemthing
crop out area of tube/screen and replace with transparency
render contents of screen into viewport for screen area first, then render the tv image over top
also, could use some overlay for scanlines



when channel is changed, show little blurb of static between channels



interactivity
first just need buttons to turn on tv and to change channel
so three rects with interaction



## Face Maker with Slouch

Definitely going to be the first thing I get made for the site


need to reimplmenet 


JS function to tell wasm which body parts to attempt to laod an what category to put them into.
even position/alignment/scale of particular assets could be defined in some json that we can then send to wasm
that way the wasm can just run the main part and do the rendering, and the JS frontend can do the rest

for now, we wil just enumerate all assets and embed directly in the wasm binary.
but maybe later we experiment with the dynamic loading thing

may even make the side panel that has the differnet body parts and the adjustments for those parts be in html/css/js and just send input into wasm through a standard interface

UI will call the following procedures to send messages to wasm runtime:
    select_class // change which body part type is selected
    change_part_next
    change_part_prev
    size_up
    size_down
    position_left
    position_right
    position_up 
    position_down
    rotate_clockwise
    rotate_counterclockwise
    spread_widen
    spread_narrow
    load_body_part(class, filename, body_part_details)


enum Body_Part_Class {
    HEAD;
    EYES;
    EARS;
    NOSE;
    MOUTH;
    GLASSES;
    HAIR;
    FACIAL_HAIR;
    HAT;
    SHIRT;
}

struct Body_Part {
    Class class;
    
    position;
    position_base;
    position_min;
    position_max;
    
    size;
    size_base;
    size_min;
    size_max;
    
    rotation;
    rotation_base;
    rotation_min;
    rotation_max;
    
    // spread is situational, probably will only apply to eyes?
    spread;
    spread_base;
    spread_min;
    spread_max;
    
    // for making things move around a bit, copy some of the relevant attributes from autumn collage icon
};


we need a good font and background in addition to the body parts
If I have the time, maybe we work in some background particle effect
have a "take picture" button to export, so maybe some nice camera graphic


if we do the side panel in html, it will probably be a bit easier to do the buttons and style the text / layout how we want it. may aslo be easier to iterate over time


"See yourself as you really are"
