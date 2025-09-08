
/*
    Current particle system is extremely basic and uses stateful particles, 
    but for many particle effects, I actually want to have sort of closed-form particles 
    which are computed based soleley on global level time and spawn time, like those in Braid.
    
    Not only for having the possibility of cheap rewind later on, but also for doing things like blending alpha with fade in/out interval which is aware of where we are in the predetermined lifetime of the particle.
    
    For now, I think the easiest thing to do will be to simply have two separate particle types distinguished by an enum and unionize them.
    That way, I don't break any of the existing particles and can simply switch individual particles from one type to another as need be.
    
    The closed_form particle type is still not really even the same as what Braid has, which is more along the lines of a particle emitter that is statless wrt the indicidual particles that are live at any given time.
        (That is, if I am remembering that presentation correctly.)
        If we wanted to implement that type of particle system, we would need to implement it as an emitter typ ewhich just rendered all its articles in and immediate-mode manner
    
    
    TODO: We really should refactor particles so that we are not needing to create and free animations for every single particle
          this is really dumb and horribly inefficient
*/

Particle :: struct {
    particle_type:      Particle_Type;
    
    animation:          Simple_Animation(8); 
    texture:            *Texture;
    palette:            Palette_ID;
    
    union {
        dynamic: struct {
            position:           Vector2;
            velocity:           Vector2;
            acceleration:       Vector2;
            scale:              Vector2 = .{ 1, 1 };
            rotation:           float;
            angular_velocity:   float;
            
            animator:           Simple_Animator(void);
            
            alpha:              float;
            alpha_velocity:     float;
            alpha_acceleration: float;
            
            lifetime:           int;
        }
        
        closed_form: struct {
            Parameter :: struct(T := float) {
                start:      T;
                end:        T;
                easing:     Easing;
                
                // if proc is null, we just use lifetime_lerp
                Easing :: struct {
                    proc:       #type (lifetime_lerp: float, param_1: float, param_2: float) -> (applied_lerp: float);
                    param_1:    float;
                    param_2:    float;
                }
                
                // here for namespacing I guess
                get :: (using parameter: Parameter(T), lifetime_lerp: float) -> T {
                    applied_lerp := lifetime_lerp;
                    if easing.proc then applied_lerp = easing.proc(lifetime_lerp, easing.param_1, easing.param_2);
                    return lerp(start, end, applied_lerp);
                }
            }
            
            timing:         enum { LEVEL; GLOBAL; };
            
            position:       Parameter(Vec2f);
            scale:          Parameter;
            rotation:       Parameter;
            color:          Parameter(Color4);
            
            // fade_in and fade_out affect the alpha channel of the color
            // start and end define range of lifetime where the fade is applied
            fade_in:        Parameter;
            fade_out:       Parameter;
            
            lifetime:       float;
            start_time:     float;
            
            // we don't really need the animator since the animation is purely a function of the applied lerp
            // but we do instead have an easing function that can be applied to the animation
            animation_easing:   Parameter(float).Easing;
        }
    }
    
    // maybe later add animation states so we can transition to another state on death or contact with certain elements in level
}

Particle_Type :: enum {
    DYNAMIC;
    CLOSED_FORM;
}

free_particle :: (using particle: *Particle) {
    // if particle_type == {
    //   case .DYNAMIC; 
        // array_reset(*dynamic.animation.frames);
        
    //   case .CLOSED_FORM;
    //     array_reset(*closed_form.animation.frames);
    // }
}

update_particle :: (using particle: *Particle) -> bool {
    if particle_type == {
      case .DYNAMIC;  using dynamic;
        velocity += acceleration;
        position += velocity;
        rotation += angular_velocity;
        alpha    += alpha_velocity;
        
        // if position.y > SCREEN_TILE_HEIGHT + 3 || position.y < -3 ||
        //    position.x > LEVEL_TILE_WIDTH   + 3 || position.x < -3 {
        //     return false;
        // }
        
        lifetime -= 1;
        return lifetime > 0;
        
      case .CLOSED_FORM;  using closed_form;
        // closed form needs the level context to know the current time
        // all that we actually need to do in update is check lifetime
        current_time  := ifx timing == .GLOBAL then seconds_since_init().(float) else context.current_level.time_since_start;
        lifetime_lerp := (current_time - start_time) / lifetime;
        return lifetime_lerp < 1;
    }
    
    return false;
}

render_particle :: (using particle: *Particle, tile_render_unit: float, offset: Vector2) {
    if particle_type == {
      case .DYNAMIC;  using dynamic;
        step_animator(*animator, animation, Game.render_delta_time);
        
        clip            := rect_to_frect(animation.frames[animator.current].clip);
        render_size     := (clip.size * scale) * tile_render_unit / tile_texture_size;
        render_position := ((position + offset) * tile_render_unit) - (render_size / 2);
        
        // TODO: render with rotation
        render_draw_quad(
            texture  = texture,
            position = render_position,
            size     = render_size,
            clip     = *clip,
            flip     = animation.frames[animator.current].flip,
            palette  = palette,
            color    = .{ 1, 1, 1, alpha },
            rotation = rotation
        );
        
      case .CLOSED_FORM;  using closed_form;
        current_time  := ifx timing == .GLOBAL then seconds_since_init().(float) else context.current_level.time_since_start;
        lifetime_lerp := (current_time - start_time) / lifetime;
        
        render_position := position.get(position, lifetime_lerp);
        render_scale    := scale   .get(scale,    lifetime_lerp);
        render_rotation := rotation.get(rotation, lifetime_lerp);
        render_color    := color   .get(color,    lifetime_lerp);
        
        fade_alpha := 1.0;
        if within_range(lifetime_lerp, fade_in.start, fade_in.end) {
            fade_alpha = delerp(fade_in.start, fade_in.end, lifetime_lerp).(float);
            if fade_in.easing.proc then fade_alpha = fade_in.easing.proc(fade_alpha, fade_in.easing.param_1, fade_in.easing.param_2);
        }
        else if within_range(lifetime_lerp, fade_out.start, fade_out.end) {
            fade_alpha = 1.0 - delerp(fade_out.start, fade_out.end, lifetime_lerp).(float);
            if fade_out.easing.proc then fade_alpha = fade_out.easing.proc(fade_alpha, fade_out.easing.param_1, fade_out.easing.param_2);
        }
        render_color.a *= fade_alpha;
        
        current_frame := *animation.frames[get_frame_index_at_time(animation, lifetime_lerp)];
        clip := rect_to_frect(current_frame.clip);
        
        render_size     := (clip.size * render_scale) * tile_render_unit / tile_texture_size; 
        render_position  = ((render_position + offset) * tile_render_unit) - (render_size / 2);
        
        // TODO: render with rotation
        render_draw_quad(
            texture  = texture,
            position = render_position,
            size     = render_size,
            clip     = *clip,
            flip     = current_frame.flip,
            palette  = palette,
            color    = render_color
        );
    }
}


// Particle_Emitter :: struct {
//     particle_type: Particle_Type;
    
//     particles: [] Particle;
    
//     texture: *Texture;
    
//     dynamic: struct {
//         position:               [2] Vec2f;
//         velocity:               [2] Vec2f;
//         acceleration:           [2] Vec2f;
//         scale:                  [2] Vec2f;
//         rotation:               [2] float;
//         rotation_velocity:      [2] float;
//         rotation_acceleration:  [2] float;
        
//         // animator: Simple_Animator;
//     }
// }





