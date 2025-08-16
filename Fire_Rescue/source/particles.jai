
/*
    Particles and Emitters are updated on a variable-timestep basis.
    Becuase of this, we don't really separate the update and render routines.
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

do_particle :: (emitter: Particle_Emitter, using particle: *Particle, delta_time: float) -> bool {
    particle.velocity          += particle.acceleration * delta_time;
    particle.position          += particle.velocity     * delta_time;
    
    particle.rotation_velocity += particle.rotation_acceleration * delta_time;
    particle.rotation          += particle.rotation_velocity     * delta_time;
    
    particle.alpha_velocity    += particle.alpha_acceleration * delta_time;
    particle.alpha             += particle.alpha_velocity     * delta_time;
    
    step_animator(*animator, animation, Game.render_delta_time);
    
    clip            := rect_to_frect(animation.frames[animator.current].clip);
    render_size     := size * render_unit;
    render_position := ((position + offset) * tile_render_unit) - (render_size / 2);
    
    lifetime_lerp   := clamp((Game.current_time - spawn_time) / lifetime, 0, 1);
    
    // fade-in and fade-out particle
    render_alpha = alpha;
    if lifetime_lerp < fade_in_time {
        render_alpha *= lifetime_lerp / fade_in_time;
    } else if lifetime_lerp > 1 - fade_out_time {
        render_alpha *= ((1 - lifetime_lerp) / fade_out_time);
    }
    
    render_draw_quad(
        texture  = texture,
        position = render_position,
        size     = render_size,
        clip     = *clip,
        flip     = animation.frames[animator.current].flip,
        palette  = palette,
        color    = .{ 1, 1, 1, render_alpha },
        rotate   = rotation
    );
    
    return spawn_time + lifetime > Game.current_time;
}

Particle_Emitter :: struct {
    my_update_particle: type_of(update_particle);
    my_render_particle: type_of(render_particle);
    
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
    
    alpha:                  Range(float);
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

init_particle_emitter :: (emitter: Particle_Emitter) {
    emitter.particles = NewArray(particle_count, desired_particle_count);
    
    if emit_frequency[0] <= 0 {
        log("Warning: emit_frquency values cannot be zero! Defaulting to 1.");
        emit_frequency[0] = 1;
    }
    if emit_frequency[1] <= 0 {
        log("Warning: emit_frquency values cannot be zero! Defaulting to 1.");
        emit_frequency[1] = 1;
    }
    
    // check fade times
}

get_first_empty_particle_slot :: (emitter: *Particle_Emitter) -> *Particle {
    for *emitter.particles  if !it.active  return it;
    return null;
}

do_particle_emitter :: (using emitter: *Particle_Emitter, offset: Vector2) {
    while Game.current_time > next_emit_time {
        p := get_first_empty_particle_slot(emitter);
        if !p {
            next_emit_time = Game.current_time + random_get_within_range(emit_frequency);
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
            
            spawn_time            = next_emit_time,
            active                = true,
        };
        
        next_emit_time += random_get_within_range(emit_frequency);
    }
    
    for *emitter.particles {
        if !do_particle(emitter, it) {
            it.active = false;
        }
    }
}







// TODO: move to another file?
Range :: struct(T: Type) { min, max: T; }

random_get_within_range :: (using range: Range(T)) -> T {
    return random_get_within_range(range.min, range.max);
}

random_get_within_range :: (min: Vector2, max: Vector2) -> Vector2 {
    return .{
        random_get_within_range(min.x, max.x),
        random_get_within_range(min.y, max.y)
    };
}