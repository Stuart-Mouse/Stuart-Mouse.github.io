/*
    general structure for visual elements, so that they may be animated based on time and game state
    TODO: in future may want to separate into Decoration template and instance 
          - prevent duplication of animation arrays
          - randomize certain properties of decoration per instance (scale, clips, particular animation)
    
    
    
    TODO: dynamically handle simple animator of any type?
        could hold animator type by pointer and use some interface proc to step it generically
        at some point someone needs to know the specific type in order to change the state though
        
    TODO: positioning and sizing based on various units
        currently, the position of some decoration is just its tile location in the game
        depending on the context in which the decoration is used, this position coudl be treated differnetly, i suppose
        however, then we can't use the position directly in render_decoration, which woudl be dumb
        so instead, we also pass an optional offset to render_decoration so that the caller can reposition it and just leave .position member as {0,0}
        
        but still, it seems there are situations where it would be nice to be able to set the position in lsd and have that still be a meaningful value, usually as some offset from the parent element's position
        e.g. we have the ambulance's graphics, which we want to render centered on the ambulance's center point
        but we can already center clips with the offset in simple_animation_frame
        
        ... I think maybe all this complication actually stems more from the fact that our simple animator is lacking
            why use Vec2i for clip/offset instead of just Vector2? just leads to more casting back and forth...
*/

Decoration :: struct {
    name:               string;
    z_index:            int; // negative is rendered behind player and guys, positive is in front
    
    position:           Vec2f;
    sizing:             Sizing_Policy;
    color_mod:          Color4 = .{1,1,1,1};
    
    texture_id:         Texture_ID;
    
    animator:           Simple_Animator(Game.Mode);
    animations:         Enumerated_Array(Game.Mode, Simple_Animation);
    particle_emitters:  [] Particle_Emitter;
}

free_decoration :: (decor: *Decoration) {
    free(decor.name);
    for *decor.animations {
        free_animation(it);
    }
    for *decor.particle_emitters {
        free_particle_emitter(it);
    }
}

render_decoration :: (decor: *Decoration, offset := Vec2f.{ 0, 0 }) {
    using Game;
    
    maybe_set_animation(*decor.animator, Game.mode, decor.animations.data);
    step_animator(*decor.animator, decor.animations.data, render_delta_time);
    current_frame := get_current_frame(decor.animator, decor.animations.data);
    clip          := current_frame.clip;
    texture       := *textures[decor.texture_id];
    
    render_scale  := get_scalar(clip.size, decor.sizing);
    render_offset := current_frame.offset * render_scale;
    
    render_rect := Rectf.{
        size     = clip.size * render_scale,
        position = decor.position + render_offset + offset,
    };
    render_rect = world_to_screen(render_rect);
    
    render_draw_quad(
        position = render_rect.position,
        size     = render_rect.size,
        texture  = texture,
        clip     = clip,
        color    = decor.color_mod,
    );
    
    for *decor.particle_emitters {
        do_particle_emitter(it, .{});
    }
}



Sizing_Policy :: struct {
    // units:          Unit;
    target_size:    float;
    scale_axis:     Axis;
}

get_scalar :: inline (size: Vec2f, rule: Sizing_Policy) -> float {
    return rule.target_size / get_axis(size, rule.scale_axis);
}
