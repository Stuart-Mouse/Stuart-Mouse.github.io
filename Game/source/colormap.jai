/*
    Since all tiles and sprites in this game will use a single color,
    we don't really need the concept of multiple colors per se.
    Instead, we just have an array of color animations, with each animated color being named.
    
    Color animaitons will be handled entirely on the CPU, since we just pass colors on the vertices.
    This is nice since we don't need to do the work of passing all the updated color colors to the GPU each frame.
*/


Color_Animation :: struct {
    name:       string;
    current:    int;
    clock:      float; 
    frames: [] struct { 
        color:      Color4;
        duration:   float;
    };
}

color_palette: [..] Color_Animation;

get_color_animation :: (index: int) -> *Color_Animation {
    if index < 0 || index >= color_palette.count  
        return *color_palette[0];
    return *color_palette[index];
}

get_current_color :: (index: int) -> Color4 {
    if index < 0 || index >= color_palette.count  
        return *color_palette[0].frames[0].color;
    anim := color_palette[index];
    return anim.frames[anim.current].color;
}

get_color_animation :: (name: string) -> *Color_Animation {
    for *color_palette  if it.name == name  return it;
    log("Error: No palette found with name '%'.", name);
    return null;
}

// if we can't find the palette, we default to 0.  
// is this bad? we dont' want to crash here since we may call this from data file, but maybe we should at least print some log...
get_color_animation_index :: (name: string) -> int {
    for color_palette  if it.name == name  return it_index;
    log("Error: No palette found with name '%'.", name);
    return 0;
}

get_current_color :: (name: string) -> Color4 {
    anim := get_color_animation(name);
    if !anim  return *color_palette[0].frames[0].color;
    return anim.frames[anim.current].color;
}


update_color_animations :: (step: float = TIMESTEP) {
    for *color_palette {
        it.clock += step;
        while it.clock >= it.frames[it.current].duration {
            if it.frames[it.current].duration < 0.001  continue it;
            it.clock -= it.frames[it.current].duration;
            it.current += 1;
            if it.current >= it.frames.count {
                it.current = 0;
            }
        }
    }
}

free_color_palette :: () {
    // skip index 0 because that is always the all-white palette
    for 1..color_palette.count-1 {
        color := *color_palette[it];
        free(color.name);
        array_free(color.frames);
    }
    array_reset(*color_palette);
}

load_color_palette :: () -> bool {
    free_color_palette();
    array_reset_keeping_memory(*color_palette);
    
    // default palette is just white
    array_add(*color_palette, .{ 
        name = "white", 
        frames = .[ .{ .{1,1,1,1}, 0 } ],
    });
    
    ok := LSD.load_and_parse_file("data/colors.lsd", #code {
        LSD.add_data_binding_to_dom(*parser, color_palette, "colors");
    });
    if !ok  return false;
    
    return true;
}
