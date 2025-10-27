/*
    Since all tiles and sprites in this game will use a single color,
    we don't really need the concept of multiple colors per se.
    Instead, we just have an array of color animations, with each animated color being named.
    
    Color animaitons will be handled entirely on the CPU, since we just pass colors on the vertices.
    This is nice since we don't need to do the work of passing all the updated color colors to the GPU each frame.
*/


Palette_ID :: #type,isa int;

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

get_color_animation :: (index: Palette_ID) -> *Color_Animation {
    if index < 0 || index >= xx color_palette.count  
        return *color_palette[0];
    return *color_palette[index];
}

get_current_color :: (index: Palette_ID, time: float) -> Color4 {
    if index < 0 || index >= xx color_palette.count {
        return color_palette[0].frames[0].color;
    }
    
    anim := color_palette[index];
    if !anim.frames {
        return color_palette[0].frames[0].color;
    }
    if anim.frames.count == 1 {
        return anim.frames[0].color;
    }
    
    total_cycle_time: float;
    for anim.frames { total_cycle_time += it.duration; }
    if total_cycle_time <= 0 {
        return anim.frames[0].color;
    }
    
    time_in_cycle := fmod_cycling(time, total_cycle_time);
    
    time_in_frame := time_in_cycle;
    current_frame: int;
    for anim.frames { 
        if time_in_frame < it.duration {
            current_frame = it_index;
            break;
        }
        time_in_frame -= it.duration;
    }
    next_frame := (current_frame + 1) % anim.frames.count;
    
    lerp_in_frame := time_in_frame / anim.frames[current_frame].duration;
    color_a := anim.frames[current_frame].color;
    color_b := anim.frames[next_frame].color;
    
    // TODO: add option to set easing function instead of just using lerp.
    //       we probably want something smoother in most cases.
    //       maybe look at the code for the color animation editor widget in get_rect and just copy that logic?
    return lerp(color_a, color_b, lerp_in_frame);
}

get_color_animation :: (name: string) -> *Color_Animation {
    for *color_palette  if it.name == name  return it;
    log("Error: No palette found with name '%'.", name);
    return null;
}

// if we can't find the palette, we default to 0.  
get_color_animation_index :: (name: string) -> Palette_ID {
    for color_palette  if it.name == name  return xx it_index;
    log("Error: No palette found with name '%'.", name);
    return 0;
}

get_current_color :: (name: string, time: float) -> Color4 {
    return get_current_color(get_color_animation_index(name), time);
}

// update_color_animations :: (step: float = TIMESTEP) {
//     for *color_palette {
//         it.clock += step;
//         while it.clock >= it.frames[it.current].duration {
//             if it.frames[it.current].duration < 0.001  continue it;
//             it.clock -= it.frames[it.current].duration;
//             it.current += 1;
//             if it.current >= it.frames.count {
//                 it.current = 0;
//             }
//         }
//     }
// }

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

save_color_palette :: (name: string) {
    path := tprint("data/%.lsd", name);
    
    using LSD;
    
    parser: Parser;
    init_parser(*parser, "");
    defer deinit_parser(*parser);
    
    append_data_node(*parser, parser.dom_root, "colors", color_palette);
    serialize_to_file(*parser, path);
}

#if EDITOR_ENABLED {

    color_palette_combo_box :: (label: *u8, value: *Palette_ID, combo_flags := ImGui.ComboFlags.None, selectable_flags := ImGui.SelectableFlags.None) -> bool {
        current_animation := get_color_animation(value.*);
        
        new_value := value.*;
        if ImGui.BeginCombo(label, temp_c_string(current_animation.name), combo_flags) {
            for color_palette {
                if ImGui.Selectable(
                    label    = temp_c_string(it.name), 
                    selected = value.* == it_index,
                    flags    = selectable_flags
                ) {
                    new_value = xx it_index;
                }
            }
            ImGui.EndCombo();
        }
        
        // set value to new value after evaluating return value condition
        defer value.* = new_value;
        return value.* != new_value;
    }
    
}