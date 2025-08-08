
Spawner :: struct  {
    spawner_type:   Spawner_Type;
    spawner_flags:  Spawner_Flags;
    
    spawn_velocity:      Vec2f;
    spawn_frequency:     float;
    spawn_timer_offset:  float;
    
    last_spawn_time:     float;
    
    exemplar_entity:     Entity_Handle;
    
    // TODO: some spawners that operate based on event trigger instead of time cycles
    
    // TODO: structure for storing particle spawner parameters
    //       and some additional things for determining when to spawn particles wrt entity spawning
    
    // animator:       Spawner_Animator;
}

Spawner_Type :: enum {
    LAUNCHER;
    // PIPE;
    
    _COUNT;
}

Spawner_Flags :: enum_flags {  };

init_spawner :: (using spawner: *Spawner) {
    level := context.current_level;
    
    slot := get_next_empty_slot(*level.entities);
    if slot != null {
        slot.occupied = true;
        slot.base.entity_flags |= .IS_SPAWNER_EXEMPLAR;
    } else {
        log("ERROR: failed to add spawner exemplar entity!");
    }
    
    
}

update_spawner :: (using spawner: *Spawner) {
    level := context.current_level;
    
    size = .{ 1, 1 }; // temporary
    
    if (last_spawn_time == 0 && level.time_since_start > spawn_frequency + spawn_timer_offset)
    || (last_spawn_time  > 0 && level.time_since_start - last_spawn_time > spawn_frequency) {
        last_spawn_time += spawn_frequency;
        
        slot := get_next_empty_slot(*level.entities);
        if slot != null {
            slot.occupied = true;
            slot.data = get(exemplar_entity).*;
            slot.base.spawner_handle = handle;
            slot.base.position = position;
            slot.base.velocity = spawn_velocity / UPDATES_PER_SECOND;
        }
    }
    
    
}

render_spawner :: (using spawner: *Spawner, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    // we really only want to render a spawner if in editor or some debug flag is set
    
    // render a semi-transparent version of the entity we are going to spawn, as well as some indication of the launch trajectory
    exemplar := get(spawner.exemplar_entity);
    if exemplar {
        render_entity(exemplar, render_unit, offset, 0.5);
    }
}
