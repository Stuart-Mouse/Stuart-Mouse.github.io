
Movement_Visualizer :: struct {
    Kind :: enum {
        NONE :: 0;
        LINE :: 1;
        DOTTED_LINE;
        CHAIN;
        TELESCOPE;
    }
    
    kind:       Kind;
    palette:    Palette_ID;
    color:      Color4;
    
    union {
        line: struct {
            p1, p2:     Vec2f;
            thickness:  float;
        };
        dotted_line: struct {
            p1, p2:     Vec2f;
            point_size: Vec2f;
        };
        telescope: struct {
            p1, p2:         Vec2f;
            min_thickness:  float;
            max_thickness:  float;
            segments:       int;
        };
    };
    
    anchor_point: Anchor_Point;
    
    Anchor_Point :: struct {
        // TODO: come up with better names for anchor point types
        Kind :: enum { 
            NONE; 
            STUD; 
        }; 
        
        kind:       Kind;
        palette:    Palette_ID;
        color:      Color4;
    };
}

// NOTE: global, gets set up in movement_visualizers.lsd
movement_visualizer_static_properties: Movement_Visualizer_Static_Properties;

Movement_Visualizer_Static_Properties :: struct {
    chain: struct {
        links: [] struct {
            animation: Simple_Animation;
            animator:  Simple_Animator(void);
        };
    };
    
    anchor_point: Enumerated_Array(Movement_Visualizer.anchor_point.Kind, struct {
        animation: Simple_Animation;
        animator:  Simple_Animator(void);
    });
}

load_movement_visualizer_resources :: () {
    using movement_visualizer_static_properties;
    
    ok := LSD.load_and_parse_file("data/movement_visualizers.lsd", #code {
        LSD.register_type(*parser, "Color4", Color4);
        LSD.register_type(*parser, "Vec2f",  Vec2f);
        LSD.register_type(*parser, "Vec2i",  Vec2i);
        
        LSD.add_data_binding_to_dom(*parser, movement_visualizer_static_properties, "d");
    });
    // if !ok  return false;
}

free_movement_visualizer_resources :: () {
    using movement_visualizer_static_properties;
    
    // for chain.links {
    //     free(it.animation.frames);
    // }
    
    // for anchor_point {
    //     free(it.animation.frames);
    // }
}

// TODO: update_movement_visualizer_static_animations


render_movement_visualizer :: (using visualizer: Movement_Visualizer, render_unit: float, offset: Vec2f) {
    anchor_point_position:  Vec2f;
    
    if kind == {
      case .LINE;
        p1 := (line.p1 + offset) * render_unit;
        p2 := (line.p2 + offset) * render_unit;
        
        time := seconds_since_init().(float);
        line_color := get_current_color(palette, time) * color;
        
        render_draw_line(p1, p2, color = line_color, thickness = line.thickness);
        
        anchor_point_position = line.p1;
        
      case .DOTTED_LINE;
        distance_between_endpoints := distance(dotted_line.p1, dotted_line.p2);
        distance_between_points    := 0.5;
        
        // TODO: we should calculate the number of points only once and then put that as a member in dotted_line
        //       that way we can render dotted line chains that appear to stretch and we won't get weird glitching when rounding is weird
        number_of_points := snap_to_nearest_unit(distance_between_endpoints / distance_between_points, 1).(int);
        move_per_point   := (dotted_line.p2 - dotted_line.p1) / number_of_points.(float) * render_unit;
        
        point      := (offset + dotted_line.p1 - dotted_line.point_size / 2) * render_unit;
        point_size := dotted_line.point_size * render_unit;
        
        for 0..number_of_points-1 {
            render_draw_quad(
                position = point,
                size     = point_size,
                palette  = palette,
                color    = color,
            );
            point += move_per_point;
        }
        
        anchor_point_position = dotted_line.p1;
        
      case .CHAIN;
        distance_between_endpoints := distance(dotted_line.p1, dotted_line.p2);
        distance_between_points    := 0.25;
        
        // TODO: we should calculate the number of points only once and then put that as a member in dotted_line
        //       that way we can render dotted line chains that appear to stretch and we won't get weird glitching when rounding is weird
        number_of_points := snap_to_nearest_unit(distance_between_endpoints / distance_between_points, 1);
        move_per_point   := (dotted_line.p2 - dotted_line.p1) / number_of_points * render_unit;
        
        point := (offset + dotted_line.p1) * render_unit;
        
        for 0..number_of_points.(int)-1 {
            links := movement_visualizer_static_properties.chain.links;
            link  := *links[it%links.count];
            current_frame := link.animation.frames[link.animator.current];
            
            clip        := rect_to_frect(current_frame.clip);
            clip_offset := current_frame.offset / tile_texture_size;
            
            render_size     := clip.size * render_unit / tile_texture_size;
            render_position := point + (clip_offset * render_unit);
            
            render_draw_quad(
                texture  = *textures.ENTITIES,
                clip     = *clip,
                flip     = current_frame.flip,
                position = render_position,
                size     = render_size,
                palette  = palette,
                color    = color,
            );
            point += move_per_point;
        }
        
        anchor_point_position = dotted_line.p1;
        
      case .TELESCOPE;
        time := seconds_since_init().(float);
        line_color := get_current_color(palette, time) * color;
        
        for 0..telescope.segments-1 {
            it_lerp := it.(float)/telescope.segments.(float);
            
            thickness := lerp(telescope.min_thickness, telescope.max_thickness, it_lerp) * render_unit;
            
            p1 := (telescope.p1 + offset) * render_unit;
            p2 := (lerp(telescope.p1, telescope.p2, 1.0-it_lerp) + offset) * render_unit;
            
            render_draw_line(p1, p2, color = line_color * .{0.5+0.5*it_lerp,0.5+0.5*it_lerp,0.5+0.5*it_lerp,1}, thickness = thickness);
        }
        
        anchor_point_position = telescope.p1;
    }
    
    // anchor point
    // static animations need to be handled from render_game and render_editor
    // get clip from current animation frame
    // render centered on anchor point, respecting clip offset
    {
        static_data := *movement_visualizer_static_properties.anchor_point[anchor_point.kind];
        if static_data.animation.frames {
            current_frame := *static_data.animation.frames[static_data.animator.current];
            
            clip := rect_to_frect(current_frame.clip);
            clip_offset := current_frame.offset / tile_texture_size;
            
            render_size := clip.size * render_unit / tile_texture_size;
            
            render_position := anchor_point_position;
            render_position  = (render_position + offset + clip_offset) * render_unit;
            
            // TODO: render with rotation if applicable?
            render_draw_quad(
                texture  = *textures.ENTITIES,
                position = render_position,
                size     = render_size,
                clip     = *clip,
                flip     = current_frame.flip,
                palette  = anchor_point.palette,
                color    = anchor_point.color
            );
        }
    }
}
