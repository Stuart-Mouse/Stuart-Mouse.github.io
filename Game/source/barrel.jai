
// TODO: oil barrel, not sure whether to make that a flag or a barrel_type


/*
    Notes about Barrels 
    
    currently barrels are always on their rolling side
    in the future, the player will be able to stand them on end as well, probably
    
    
    
*/

Barrel :: struct {
    using #as base: Entity;
    
    type:   Barrel_Type;
    flags:  Barrel_Flags;
}

Barrel_Type :: enum { BARREL; ROCK; TRASH_CAN; };

// Barrel_Flags :: enum_flags {  };


barrel_physics, rock_physics, trash_can_physics: Enemy Physics;
init_barrel_physics :: () {
    barrel_physics = .{
        gravity          = default_player_physics.gravity * 0.85,
        ground_accel     = default_player_physics.ground_accel,
        air_accel        = default_player_physics.air_accel,
        ground_friction  = default_player_physics.ground_friction,
        air_friction     = default_player_physics.air_friction,
        stop_friction    = default_player_physics.stop_friction,
        air_speed_max    = default_player_physics.top_airspeed,
        max_fall_speed   = default_player_physics.max_fall_speed,
        ground_speed_max = default_player_physics.top_airspeed,
    };
    
    rock_physics = barrel_physics;
    
    
}


update_barrel :: (using barrel: *Barrel) -> bool {
    if barrel == null  return true;
    
    phys: Enemy_Physics;
    if barrel_type == {
      case .BARREL;     phys = barrel_physics;
      case .ROCK;       phys = rock_physics;
      case .TRASH_CAN;  phys = trash_can_physics;
    }
    
    
    
}


render_barrel :: (using barrel: *Barrel, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    
}


barrel_collide_plumber :: (barrel: *Barrel, plumber: *Player, entity_index: int) {
    p_rect := get_collision_rect(plumber);
    b_rect := get_collision_rect(barrel);
    
    // TODO: make direction-independent
    // this will likely require quite a bit of work, need to consider how we want to rotate/transform collision rects or if we want to do something non-rect based
    if aabb_frect(p_rect, b_rect) {
        stomp_margin :: 2.0 / 16.0; // 2 pixels
        player_is_standing_on := p_rect.y + p_rect.h - max(plumber.velocity.y, 0) < e_rect.y + stomp_margin;
        
        if player_is_standing_on {
            plumber.position.y -= max((p_rect.y + p_rect.h) - e_rect.y, 0);
            plumber.entity_flags |= .ON_GROUND;
            plumber.ground_velocity = position - position_prev;
            if plumber.velocity.y > 0  plumber.velocity.y = 0;
            
            // player can pick up barrel when standing on top of it
            // TDOO: 
            if plumber.controller[Player_Input_Keys.THROW].state == .PRESSED {
                enemy.entity_flags |= .HELD;
                if template.flags & .SHELLED {
                    flags &= ~.MOVING;
                    flags ^=  .FLIPPED;
                    shell.clock = 60 * 5;
                } else {
                    enemy.rotation = PI;
                }
                
                plumber.held_entity_index = entity_index;
                plumber.pickup_lerp = 0;
            }
        }
        
        if do_player_damage {
            // plumber_take_damage(plumber);
        }
    }
}