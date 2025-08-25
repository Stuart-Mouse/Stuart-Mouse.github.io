
/*
    Particles and Emitters are updated on a variable-timestep basis.
    Becuase of this, we don't really separate the update and render routines.

    TODO: definitely need to set proper sizing modes based on a single axis, 
          rather than having absolute sizing where each axis is scaled independently

*/


Particle :: struct {
    position:               Vector2;
    velocity:               Vector2;
    acceleration:           Vector2;
    
    size:                   Vector2;
    size_velocity:          Vector2;
    size_acceleration:      Vector2;
    
    rotation:               float;
    rotation_velocity:      float;
    rotation_acceleration:  float;
    
    alpha:                  float;
    alpha_velocity:         float;
    alpha_acceleration:     float;
    
    fade_in\_time:          float;
    fade_out_time:          float;
    
    animator:               Simple_Animator(void);
    
    spawn_time:             float;
    lifetime:               float;
    
    active:                 bool;
    // maybe later add animation states so we can transition to another state on death or contact with certain elements in level
}

do_particle :: (using particle: *Particle, emitter: Particle_Emitter, delta_time: float) -> bool {
    velocity          += acceleration * delta_time;
    position          += velocity     * delta_time;
    
    rotation_velocity += rotation_acceleration * delta_time;
    rotation          += rotation_velocity     * delta_time;
    
    alpha_velocity    += alpha_acceleration * delta_time;
    alpha             += alpha_velocity     * delta_time;
    
    step_animator(*animator, emitter.animation, Game.render_delta_time);
    
    offset := Vec2f.{ 0, 0 }; // TODO: make parameter
    
    current_frame   := get_current_frame(animator, emitter.animation);
    clip            := current_frame.clip;
    render_size     := size * Game.tile_render_unit;
    render_position := ((position + offset) * Game.tile_render_unit) - (render_size / 2) + Game.viewport.position;
    
    lifetime_lerp   := clamp((Game.time_since_start - spawn_time) / lifetime, 0, 1);
    
    // fade-in and fade-out particle
    render_alpha := alpha;
    if lifetime_lerp < fade_in_time {
        render_alpha *= lifetime_lerp / fade_in_time;
    } else if lifetime_lerp > 1 - fade_out_time {
        render_alpha *= ((1 - lifetime_lerp) / fade_out_time);
    }
    
    texture := *Game.textures[emitter.texture_id];
    
    render_draw_quad(
        texture  = texture,
        position = render_position,
        size     = render_size,
        clip     = *clip,
        flip     = current_frame.flip,
        // palette  = palette,
        color    = .{ 1, 1, 1, render_alpha },
        rotate   = rotation
    );
    
    return spawn_time + lifetime > Game.time_since_start;
}

Particle_Emitter :: struct {
    // user can set desired_particle_count in LSD, 
    // then we use that to init the particles array
    desired_particle_count: int; 
    
    particles:              [] Particle;
    texture_id:             Texture_ID;
    animation:              Simple_Animation;
    
    velocity:               Range(Vector2);
    acceleration:           Range(Vector2);
    
    size:                   Range(Vector2);
    size_velocity:          Range(Vector2);
    size_acceleration:      Range(Vector2);
    
    rotation:               Range(float);
    rotation_velocity:      Range(float);
    rotation_acceleration:  Range(float);
    
    alpha:                  Range(float) = .{ 1, 1 };
    alpha_velocity:         Range(float);
    alpha_acceleration:     Range(float);
    
    lifetime:               Range(float);
    
    fade_in\_time:          Range(float);
    fade_out_time:          Range(float);
    
    emit_frequency:         Range(float);
    emit_box:               Rectf;
    
    next_emit_time:         float;
    
    flags: Flags;
    Flags :: enum_flags {
        // RENDER_PARTICLES_RELATIVE_TO_EMITTER;
    }
}

free_particle_emitter :: (using emitter: *Particle_Emitter) {
    array_free(emitter.particles);
}

prep_particle_emitter :: (using emitter: *Particle_Emitter) {
    particles = NewArray(desired_particle_count, Particle);
    
    check_emit_frequency :: inline (value: *float, name: string) {
        if value.* <= 0 {
            log("Warning: % must be greater than zero! Defaulting to 1.", name);
            value.* = 1;
        }
    }
    check_emit_frequency(*emit_frequency.min,  "emit_frequency.min");
    check_emit_frequency(*emit_frequency.max,  "emit_frequency.max");
        
    check_fade_time :: inline (value: *float, name: string) {
        if value.* < 0 {
            log("Warning: % must be between 0 and 1! Clamping value.", name);
            value.* = clamp(value.*, 0, 1);
        }
    }
    check_fade_time(*fade_in_time.min,  "fade_in_time.min");
    check_fade_time(*fade_in_time.max,  "fade_in_time.max");
    check_fade_time(*fade_out_time.min, "fade_out_time.min");
    check_fade_time(*fade_out_time.max, "fade_out_time.max");
}

get_first_empty_particle_slot :: (emitter: *Particle_Emitter) -> *Particle {
    for *emitter.particles  if !it.active  return it;
    return null;
}

do_particle_emitter :: (using emitter: *Particle_Emitter, offset: Vector2) {
    while Game.time_since_start > next_emit_time {
        p := get_first_empty_particle_slot(emitter);
        if !p {
            next_emit_time = Game.time_since_start + random_get_within_range(emit_frequency);
            break;
        }
        
        p.* = Particle.{
            position              = offset + emit_box.position + random_get_within_range(Vector2.{}, emit_box.size),
            velocity              = random_get_within_range(velocity),
            acceleration          = random_get_within_range(acceleration),
            size                  = random_get_within_range(size),
            size_velocity         = random_get_within_range(size_velocity),
            size_acceleration     = random_get_within_range(size_acceleration),
            rotation              = random_get_within_range(rotation),
            rotation_velocity     = random_get_within_range(rotation_velocity),
            rotation_acceleration = random_get_within_range(rotation_acceleration),
            alpha                 = random_get_within_range(alpha),
            alpha_velocity        = random_get_within_range(alpha_velocity),
            alpha_acceleration    = random_get_within_range(alpha_acceleration),
            lifetime              = random_get_within_range(lifetime),
            
            fade_in\_time         = random_get_within_range(fade_in\_time),
            fade_out_time         = random_get_within_range(fade_out_time),
            
            spawn_time            = next_emit_time,
            active                = true,
        };
        
        next_emit_time += random_get_within_range(emit_frequency);
    }
    
    for *emitter.particles {
        if !it.active  continue;
        if !do_particle(it, emitter, Game.render_delta_time) {
            it.active = false;
        }
    }
}


// manual particle emitting procedures

// emit particles using the particle emitter's properties to initialize
// TODO: create a version that allows user to manually override particular initializer properties
//       this will require either making some separate Particle_Initializer struct or having a lot of optional parameters
emit_particles :: (using emitter: *Particle_Emitter, count: int, offset: Vector2) {
    for 0..count-1 {
        p := get_first_empty_particle_slot(emitter);
        if !p  return;
        
        p.* = Particle.{
            position              = offset + emit_box.position + random_get_within_range(Vector2.{}, emit_box.size),
            velocity              = random_get_within_range(velocity),
            acceleration          = random_get_within_range(acceleration),
            size                  = random_get_within_range(size),
            size_velocity         = random_get_within_range(size_velocity),
            size_acceleration     = random_get_within_range(size_acceleration),
            rotation              = random_get_within_range(rotation),
            rotation_velocity     = random_get_within_range(rotation_velocity),
            rotation_acceleration = random_get_within_range(rotation_acceleration),
            alpha                 = random_get_within_range(alpha),
            alpha_velocity        = random_get_within_range(alpha_velocity),
            alpha_acceleration    = random_get_within_range(alpha_acceleration),
            lifetime              = random_get_within_range(lifetime),
            
            spawn_time            = Game.time_since_start,
            active                = true,
        };
    }
}





// TODO: move to another file?
Range :: struct(T: Type) { min, max: T; }

random_get_within_range :: (using range: Range($T)) -> T {
    return random_get_within_range(range.min, range.max);
}

random_get_within_range :: (min: Vector2, max: Vector2) -> Vector2 {
    return .{
        random_get_within_range(min.x, max.x),
        random_get_within_range(min.y, max.y)
    };
}