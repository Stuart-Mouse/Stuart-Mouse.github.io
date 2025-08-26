
Player_Physics :: struct {
    ground_friction:            float;
    stop_friction:              float;
    air_friction:               float;
    top_airspeed:               float;
    coyote_time:                float;
    // gravity:                    float;
    
    jump_gravity:               float;
    hold_gravity:               float;
    fall_gravity:               float;
    fastfall_gravity:           float;
    
    jump_height:                float;
    jump_release_height:        float;
    run_jump_height:            float;
    
    jump_force:                 float;
    run_jump_force:             float;
    jump_release_force:         float;
    
    // TODO: reintroduce ledge grab and ledge jump after simplifying collision and physics
    // long_jump_speed:            float;
    // long_jump_height:           float;
    // long_jump_force:            float;
    // ledge_jump_height:          float;
    // ledge_jump_force:           float;
    
    max_fall_speed:             float;
    max_fastfall_speed:         float;
    
    run_speed:                  float;
    run_accel:                  float;
    air_accel:                  float;
    
    fastfall_jerkdown:          float;
    swimspeed:                  float;
    turnaround_boost:           float;
    
    ground_friction_slippery:   float;
    stop_friction_slippery:     float;
    speed_mod_slippery:         float;
    accel_mod_slippery:         float;
    
    ground_friction_sticky:     float;
    stop_friction_sticky:       float;
    speed_mod_sticky:           float;
    accel_mod_sticky:           float;
    
    
    throw_velocity:             Vec2f;
    throw_up_velocity:          Vec2f;
    
    semisolid_drop_time:        float;
    
    // skid_decel: float;
    // release_decel: float;
    bounce_height: float;
    bounce_force: float;
    // hit_ceiling: float;
}


Player_Input_Keys :: enum {
    UP;
    DOWN;
    LEFT;
    RIGHT;
    RUN;
    JUMP;
    THROW; // also pick things up
    
    CHANGE_GRAVITY;
};

Player_Controller :: Enumerated_Array(Player_Input_Keys, Input_Key);


Player_Animation_States :: enum {
    STAND;
    WALK;
    SKID;
    JUMP;
    FALL;
    LAND;
    CROUCH;
    DEAD;
    PICKUP;
    THROW;
};

Player_Animations :: Enumerated_Array(Player_Animation_States, Simple_Animation(0));
Player_Animator   :: Simple_Animator(Player_Animation_States);


Player_Template :: struct {
    // player templates are uniquely identified by combination of character name and powerup id
    name:                       string;
    character_name:             string;
    alt_id:                     int;
    flags:                      Flags;
    
    uuid:                       u64;
    palette:                    int;
    animations:                 Player_Animations;
    noises:                     Entity_Sounds;
    physics:                    Player_Physics;
    collision_size:             Vec2f;
    
    Flags :: enum_flags {
        CAN_BREAK_BLOCKS;
    };
}

player_templates: [..] Player_Template;

Player :: struct {
    using #as base: Entity;
    entity_type = .PLAYER;
    
    template_index:         int;
    state:                  State;
    
    is_dead:                int;
    jump_cooldown:          int;
    semisolid_drop_timer:   int;
    ledge_grab:             int;
    last_jump_button_down:  int;
    on_ground:              int; // = counts up on ground (0 +), counts down off ground (-1 -)

    held_entity_handle:     Entity_Handle = .{ -1, -1 };
    pickup_lerp:            float;
    
    // camera stuff
    facing:                 Direction;
    
    collision_points:       Enumerated_Array(Direction, Tilemap_Collision_Point);
    animator:               Player_Animator;
    controller_index:       int;
    
    lives:                  int;
    max_lives:              int;
    temp_lives:             int;
    coins:                  int;
    iframes:                int;
    
    camera: struct {
        focus_point:       Vector2;
        facing_weight:     float;
    }
    
    // info for non-standard player state
    warp: struct {
        clock:              int;
        handle:             Entity_Handle;
    }
    
    State :: enum {
        STANDARD :: 0;
        ENTERING_WARP;
        EXITING_WARP;
    }
}

snap_player_camera_focus_point :: (player: *Player) { 
    player.position_prev = player.position;
    player.camera.focus_point = player.position;
    player.camera.facing_weight = 0;
}

is_vulnerable :: (using player: *Player) -> bool {
    if state == {
      case .ENTERING_WARP;   return false;
    }
    if iframes > 0  return false;
    return true;
}

set_template :: (player: *Player, character_name: string, alt_id := 0) {
    set_template(player, find_player_template_index(character_name, alt_id));
}

set_template :: (player: *Player, index: int) {
    if index < 0 || index >= player_templates.count  return;
    template := *player_templates[index];
    player.template_index = index;
    player.palette        = template.palette;
    player.size           = template.collision_size;
}

get_template :: (player: Player) -> *Player_Template { 
    if player.template_index == -1 return null;
    return *player_templates[player.template_index]; 
}

// NOTE: we get the controller as an array view so that it can be indexed directly and modified. Otherwise, we would need to deref before indexing.
get_controller :: inline(player: Player) -> *Player_Controller {
    return *Game.player_controllers[player.controller_index];
}

find_player_template_index :: (character_name: string, alt_id := 0) -> int {
    for player_templates
        if it.character_name == character_name 
        && it.alt_id     == alt_id
            return it_index;
    log("Error: unable to find player template '%', alt_id %", character_name, alt_id);
    log("\tplayer_templates:");
    for player_templates  log("\t% %", it.name, it.alt_id);
    return -1;
}

init_player :: (player: *Player, template_name := "Guy") {
    player.* = .{};
    set_template(player, template_name, 0);
}

init_player_for_new_level :: (using player: *Player, level: *Level_Layout) {
    // TODO: allow player to carry entity between levels
    held_entity_handle = .{};
    warp = .{};
    
    collision_data     = .{};
    collision_points   = .{};
    
    // TODO: will actually have to check for means of entering level later, and act accordingly
    position = level.player_debug_spawn;
    velocity = .{};
    snap_player_camera_focus_point(player);
}

begin_entering_warp :: (player: *Player, warp: *Warp) {
    player.state = .ENTERING_WARP;
    player.warp = .{
        clock  = (WARP_DOOR_ENTRY_TIME * updates_per_second).(int),
        handle = warp.handle,
    };
    create_door_entry_particles(player.position);
}

begin_exiting_warp :: (player: *Player, warp: *Warp) {
    player.state = .EXITING_WARP;
    player.position = warp.position;
    snap_player_camera_focus_point(player);
    player.warp = .{
        clock  = (WARP_DOOR_EXIT_TIME * updates_per_second).(int),
        handle = warp.handle,
    };
}

update_player :: (using player: *Player) {
    level      := context.current_level;
    template   := get_template(player);
    if !template  return;
    
    physics    := *template.physics;
    controller := get_controller(player);
    
    SPEED_EPSILON := 0.1 / updates_per_second;
    
    should_do_physics           := true;
    should_do_tilemap_collision := true;
    should_do_entity_collision  := true;
    
    if state == {
      case .ENTERING_WARP;
        warp.clock -= 1;
        
        if warp.clock <= 0 {
            warp_entity := get(warp.handle).(*Warp);
            if warp_entity {
                // commit the warp and actually throw up the warp event for game to handle
                Game.event_flags |= .WARP;
                Game.warp_event = .{ warp_entity.dst_locator, false };
                log("set warp event: %", Game.warp_event);
            } else {
                // kick player back out of door
                state = .STANDARD;
                velocity = .{};
                create_door_entry_particles(player.position);
            }
        } else {
            warp_entity := get(warp.handle).(*Warp);
            if warp_entity then warp_entity.warp_flags |= .PLAYER_USING_THIS_FRAME;
        }
        
        // still need to do camera update!
        should_do_physics = false;
        should_do_tilemap_collision = false;
        should_do_entity_collision = false;
        
      case .EXITING_WARP;
        warp.clock -= 1;
        
        if warp.clock <= 0 {
            warp_entity := get(warp.handle).(*Warp);
            if warp_entity {
                player.position = warp_entity.position;
            }
            state = .STANDARD;
            velocity = .{};
            create_door_entry_particles(player.position);
        } else {
            warp_entity := get(warp.handle).(*Warp);
            if warp_entity then warp_entity.warp_flags |= .PLAYER_USING_THIS_FRAME;
        }
        
        // still need to do camera update!
        should_do_physics = false;
        should_do_tilemap_collision = false;
        should_do_entity_collision = false;
    }
    
    // timers / counters
    if iframes              > 0  iframes              -= 1;
    if jump_cooldown        > 0  jump_cooldown        -= 1;
    if semisolid_drop_timer > 0  semisolid_drop_timer -= 1;
    
    if is_dead > 0 {
        is_dead += 1;
        if is_dead < (0.5 * updates_per_second).(int) {
            // set player velocity up, but don't actually move player
            // TODO: calculating this every frame here is dumb, we should do this in some kill_player() proc
            player.velocity.y = -compute_jump_force(3, template.physics.hold_gravity);
            player.velocity.x = 0;
        } else if is_dead > (3.0 * updates_per_second).(int) && position.y > level.bounds.y + level.bounds.h + 2 {
            player.lives -= 1;
            
            Game.event_flags |= .SCENE_TRANSITION;
            Game.scene_transition = .{ 
                src_scene = .LEVEL, 
                dst_scene = .LEVEL, 
                clock     = (Scene_Transition.TRANSITION_FADE_TIME * updates_per_second).(int)
            };
            
            Game.event_flags |= .WARP;
            Game.warp_event = .{ Game.last_significant_warp, true };
            
            init_player(player);
            // TODO: later do scene transition to level into screen, then back into level
            //       or check some worldmap flag for immediate restart (kaizo?)
        } else {
            player.velocity.y += template.physics.hold_gravity;
            player.position += player.velocity;
        }
        return;
    }
    
    last_jump_button_down += 1;
    if controller.JUMP.state == .PRESSED {
        last_jump_button_down = 0;
    }
    
    // general per-frame state management
    vel_y_prev := velocity.y;
    position_prev = position;
    
    
    if should_do_physics {
        // if both right and left are down, bring the player to a standstill
        if controller.RIGHT.state & controller.LEFT.state & .PRESSED {
            if velocity.x < 0 then controller.LEFT.state = 0;
            else controller.RIGHT.state = 0;
        }
        
        // horizontal velocity calculations
        {
            velocity_relative_to_ground := velocity - ground_velocity;
            
            top_speed := physics.run_speed;
            accel     := physics.run_accel;
            
            // apply friction
            if on_ground >= -5 {
                ground_friction := physics.ground_friction;
                stop_friction   := physics.stop_friction;
                
                applied_friction := 1.0;
                
                // whether player can stick to moving ground well should also depend on absolute speed
                player_ground_stick_thresh_lower := 1.0 / updates_per_second;
                player_ground_stick_thresh_upper := 2.0 / updates_per_second;
                
                left\  _pressed := (controller.LEFT .state & .PRESSED).(bool);
                right\ _pressed := (controller.RIGHT.state & .PRESSED).(bool);
                neither_pressed := !(left_pressed || right_pressed);
                
                if neither_pressed || (right_pressed && velocity_relative_to_ground.x < 0) || (left_pressed && velocity_relative_to_ground.x > 0) {
                    relative_ground_speed_difference := abs(velocity_relative_to_ground.x);
                    if relative_ground_speed_difference < player_ground_stick_thresh_lower {
                        applied_friction = 0;
                    } else {
                        actual_stop_friction := ground_friction;
                        if relative_ground_speed_difference < player_ground_stick_thresh_upper {
                            lerp_t := clamp(delerp(0, player_ground_stick_thresh_upper, relative_ground_speed_difference), 0, 1);
                            actual_stop_friction = lerp(stop_friction, ground_friction, lerp_t).(float);
                        }
                        applied_friction = actual_stop_friction;
                    }
                } else if abs(velocity_relative_to_ground.x) > top_speed {
                    applied_friction = ground_friction;
                }
                
                velocity.x = lerp(ground_velocity.x, velocity.x, applied_friction);
            }
            else { // air friction and accel
                velocity_relative_to_ground = velocity;
                // accel = physics.air_accel;
                
                if abs(velocity.x) > physics.top_airspeed {
                    velocity.x *= physics.air_friction;
                }
                if (((controller.RIGHT.state & .PRESSED) && velocity.x < 0)
                 || ((controller.LEFT .state & .PRESSED) && velocity.x > 0)) {
                    accel *= physics.turnaround_boost;
                }
            }
            
            // TODO: ability for player to accelerate should depend on both absolute velocity and velocity of player relative to the ground they're standing on
            applicable_accel: float;
            if controller.RIGHT.state & .PRESSED {
                facing = .R;
                applicable_accel = clamp(top_speed - velocity_relative_to_ground.x, 0, accel);
            }
            if controller.LEFT.state  & .PRESSED {
                facing = .L;
                applicable_accel = clamp(-top_speed - velocity_relative_to_ground.x, -accel, 0);
            }
            velocity.x += applicable_accel;
        }
        
        // jump and dive calculations 
        do_blend_y_vel := on_ground < 0;
        {
            if controller.JUMP.state & .PRESSED {
                if jump_cooldown == 0 {
                    do_normal_jump := (on_ground >= 0 && (last_jump_button_down < physics.coyote_time.(int) /*|| ground_modifier == TILE_MOD_BOUNCY*/));
                    do_coyote_jump := (on_ground <  0 && -on_ground < physics.coyote_time.(int) && (controller.JUMP.state == .PRESSED) /*&& ground_modifier != TILE_MOD_BOUNCY*/);
                    
                    if do_normal_jump || do_coyote_jump {
                        if (entity_flags & .GROUND_IS_SEMISOLID) && (controller.DOWN.state & .PRESSED) {
                            semisolid_drop_timer = physics.semisolid_drop_time.(int);
                            velocity.y = (ground_velocity.y * 0.75);// + physics.fastfall_jerkdown;
                            // TODO: play different noise
                        } else {
                            velocity.y = (ground_velocity.y * 0.75) - physics.jump_force;
                            play(*template.noises.jump);
                        }
                        
                        do_blend_y_vel = false;
                        ground_velocity *= 0.75;
                        jump_cooldown = physics.coyote_time.(int);
                    }
                }
            }
            else if controller.JUMP.state == .RELEASED && velocity.y < -physics.jump_release_force {
                velocity.y = -physics.jump_release_force;
            }
        }
        
        gravity := physics.fall_gravity;
        if controller.JUMP.state & .PRESSED {
            gravity = ifx velocity.y < 0 then physics.jump_gravity else physics.hold_gravity;
        }
        
        max_fall_speed := physics.max_fall_speed;
        
        // if dive button down
        if controller.DOWN.state & .PRESSED {
            if controller.DOWN.state == .PRESSED {
                if on_ground >= 0 {
                    /*if (p->ledge_grab > 0) {
                        p->ledge_grab = -(updates_per_second * (3.0 / 16.0));
                        p->static_velocity.y = p->ground_velocity.y;
                    }*/
                    // if (p->ground_modifier == TILE_MOD_STICKY) {
                    //     p_static_velocity.y += physics.fastfall_jerkdown;
                    // }
                } else {
                    if velocity.y < 0 then velocity.y = 0;
                    velocity.y += physics.fastfall_jerkdown;
                }
            }
            if velocity.y > 0 {
                gravity = physics.fastfall_gravity;
                max_fall_speed = physics.max_fastfall_speed;
            }
        }
        
        velocity.y = min(velocity.y + gravity, max_fall_speed);
        
        position.x += velocity.x;
        if do_blend_y_vel {
            // average y velocity over 2 frames to prevent weird floating point error
            // I forgot where I got this idea from but it works. If I could remember I would like to give credit...
            position.y += (vel_y_prev + velocity.y) / 2.0;
        } else {
            position.y += velocity.y;
        }
    }
    
    on_ground_this_frame := false;
    player.entity_flags &= ~.GROUND_IS_SEMISOLID;
    
    if should_do_tilemap_collision {
        player.collision_data = .{};
        player.collision_points = .{};
        standing_on_tile_info: *Tile_Info;
        
        for *tilemap, tilemap_index: level.tilemaps {
            do_tilemap_collision(tilemap, player);
            
            if collision_data.on_ground {
                on_ground_this_frame = true;
                
                for Direction.[ .DL, .DR, .D ] {
                    standing_on_tile_info = ifx collision_points[it].tile_info else standing_on_tile_info;
                }
            }
            
            if collision_data.velocity_in_tilemap.y < 0 {
                for dir: Direction.[ .U, .UL, .UR ] {
                    point := collision_points[dir];
                    if point.had_collision && point.direction_out == .U {
                        bump_tile(tilemap_index, point.tile_index, ifx template.flags & .CAN_BREAK_BLOCKS then .BIG_PLUMBER else .SMALL_PLUMBER, point.direction_out, collision_data.velocity_in_tilemap);
                    }
                }
            }
            
            // collect coins
            for collision_points {
                if it.tile_ptr == null  continue;
                if get_tile_info(it.tile_ptr).collision.type == .COIN {
                    award_coins(player, 1);
                    remove_tile(it.tile_ptr);
                }
            }
            
            // for dir: Direction.[ .D, .DL, .DR ] {
            //     point := collision_data.points[dir];
            //     if point.had_collision && tile_is_bumping(point.tile_ptr) {
            //         velocity.y -= 0.15;
            //         break;
            //     }
            //     if length(point.velocity_adjust) > (0.0005 * updates_per_second) { 
            //         play(*template.noises.land);
            //     }
            // }
            
            // print_vars(collision_data.position_in_tilemap);
        }
        
        if standing_on_tile_info && (standing_on_tile_info.collision.flags & .SEMISOLID) {
            player.entity_flags |= .GROUND_IS_SEMISOLID;
        }
    }
    
    if should_do_entity_collision {
        entity_flags &= ~.ON_GROUND;
        for *level.entities {
            player_collide_entity(player, it, it_index);
        }
        on_ground_this_frame ||= (entity_flags & .ON_GROUND).(bool);
    }
    
    // increment player on/off ground timer
    if on_ground >= 0 {
        on_ground = ifx on_ground_this_frame then on_ground + 1 else -1;
    } else {
        on_ground = ifx on_ground_this_frame then 0 else on_ground - 1;
    }
    
    
    // camera stuff
    if state == {
      case .ENTERING_WARP;
      case .EXITING_WARP;
        warp_entity := get(warp.handle);
        if warp_entity {
            camera.focus_point = warp_entity.position;
        }
        
      case;
        inst_vel    := position - position_prev;
        focus_point := position + inst_vel * camera_constants.focus_vel_scalar;
        
        // adjust facing_weight
        if on_ground > xx (0.0 * updates_per_second) {
            MOVE_SPEED := 1.0 / (1.0 * updates_per_second);
            
            if      (facing == .L && camera.facing_weight > -1.0) camera.facing_weight -= MOVE_SPEED; // left
            else if (facing == .R && camera.facing_weight <  1.0) camera.facing_weight += MOVE_SPEED; // right
            else { // neutral
                if      (camera.facing_weight > 0) camera.facing_weight -= MOVE_SPEED;
                else if (camera.facing_weight < 0) camera.facing_weight += MOVE_SPEED;
            }
        }
        
        focus_point.x += camera.facing_weight * camera_constants.focus_distance;
        camera.focus_point.x = (camera.focus_point.x * (camera_constants.focus_lerp)) + (focus_point.x * (1.0 - camera_constants.focus_lerp));
        camera.focus_point.y = (camera.focus_point.y * (camera_constants.focus_lerp)) + (focus_point.y * (1.0 - camera_constants.focus_lerp));
    }
    
    if should_do_physics {
        // throw held entity
        held_entity := get(held_entity_handle);
        if held_entity {
            if !(.HELD & held_entity.entity_flags) {
                held_entity_handle.index = -1;
            } else {
                entity_offset := Vec2f.{ 0, (size.y + held_entity.size.y) / 2 };
                held_entity.position = position + lerp(entity_offset, -entity_offset, pickup_lerp);
                held_entity.velocity = position - position_prev; // before processing possible throw
    
                if pickup_lerp < 1 {
                    pickup_lerp = min(pickup_lerp + 7.0/updates_per_second, 1);
                }
                else {
                    if controller.THROW.state == .PRESSED {
                        held_entity.entity_flags &= ~.HELD;
                        held_entity.entity_flags |=  .THROWN;
                        held_entity.ticks_since_thrown = 0;
                        
                        if held_entity.entity_type == .ENEMY {
                            enemy    := held_entity.(*Enemy);
                            template := *enemy_templates[enemy.template_index];
                        }
                        
                        // TODO: consider rotation from gravity in holding/throwing entities
                        throw_velocity := ifx controller.UP.state & .PRESSED 
                            then physics.throw_up_velocity
                            else physics.throw_velocity;
                        
                        if facing == .L then throw_velocity.x *= -1;
                        held_entity.velocity = (velocity * 0.5) + throw_velocity;
                        
                        held_entity_handle.index = -1;
                        
                        // manually eat the 'pressed' part of input and switch to down state
                        // this prevents player from being able to throw held entity and pick up another on the same frame
                        controller.THROW.state = .DOWN; 
                        
                        // TODO: throw noise should probably go on entity being thrown, not on entity doing the throwing but ok.
                        play(*template.noises.throw);
                        maybe_set_animation(*animator, .THROW, template.animations.data);
                    }
                }
            }
        }
    }
}

render_player :: (using player: *Player, render_unit: float, offset: Vector2) {
    template := get_template(player);
    if !template  {
        log("no template!");
        return;
    }
    
    // for now, no animation to play when entering a door
    // we will just not render the player while in this state
    if state == {
      case .ENTERING_WARP; return;
      case .EXITING_WARP;  return;
    }
    velocity_relative_to_ground := velocity - ground_velocity;
    
    anim_state := animator.state;
    if is_dead > 0 {
        anim_state = .DEAD;
    } else {
        if anim_state != .THROW || (animator.flags & .STOPPED) {
            // if flags & .CROUCHING {
            //     anim_state = .CROUCH;
            // }
            // else 
            if on_ground < -2 {
                if velocity.y <= 0 {
                    anim_state = .JUMP;
                } else {
                    anim_state = .FALL;
                }
            }
            // else if on_ground < 6 && abs(velocity.x) < (physics.run_speed * 0.25) {
            // else if on_ground < 6 {
            //     anim_state = .SKID;
            // }
            else if abs(velocity_relative_to_ground.x) < 0.75 / updates_per_second {
                anim_state = .STAND;
            }
            // else if ((facing == .L) != (velocity_relative_to_ground.x < 0)) || (entity_flags & .SLIDING) {
            //     anim_state = .SKID;
            // } 
            else {
                anim_state = .WALK;
            }
        }
    }
    maybe_set_animation(*animator, anim_state, template.animations.data);
    
    
    // if on_ground >= 0 {
    //     walk_noise_accumulator += abs(velocity_relative_to_ground.x);
    //     if (walk_noise_accumulator > 70.0 / updates_per_second) {
    //         walk_noise_accumulator = 0;
    //         play(*template.noises.land);
    //     }
    // }
    
    // TODO: maybe the animation for player walking should just be beased on how long they've been holding the button... that way regardless of the actual surface they're walking on it shows something like the effort the player character is exerting to walk?
    // TODO: velocity relative to ground is also not quite right here, since what we really want is velocity along the surface player is walking on
    //       which would be like magnitude of player velocity_relative_to_ground along normal of (last_ground_angle + 90)
    step := (ifx anim_state == .WALK then abs(velocity_relative_to_ground.x) * updates_per_second else 1.0);
    step *= Game.render_delta_time;
    step_animator(*animator, template.animations.data, step); // TODO: adjust for delta time
    
    current_animation := *template.animations[animator.state];
    current_frame     := *current_animation.frames[animator.current];
    clip := rect_to_frect(current_frame.clip);
    flip: Direction_Flip = ifx facing == .L then .HORIZONTAL else .NONE;
    
    // @Hack: alter clip to use player hold frames instead of normal walking frames
    if anim_state == .WALK || anim_state == .STAND || anim_state == .JUMP {
        if player.held_entity_handle.index >= 0 {
            clip.x += 32;
        }
    }
    
    self_offset     := Vec2f.{ 0, size.y/2 } - (clip.size * .{ 0.5, 1.0 } / tile_texture_size);
    render_position := (position + offset + self_offset) * render_unit;
    render_size     := clip.size * render_unit / tile_texture_size;
    
    alpha := 1.0;
    
    render_draw_quad(
        texture       = *plumber_texture,
        position      = render_position,
        size          = render_size,
        clip          = *clip,
        flip          = flip,
        palette       = palette,
        rotate        = (gravity_angle - 90) * PI /180,
        color         = .{ 1, 1, 1, alpha },
        depth         = 0
    );
    
    render_position = (position + offset) * render_unit;
    // render_draw_line(render_position, render_position + (run_normal * render_unit));
    // render_draw_line(render_position, render_position + (last_velocity_adjust     * render_unit * 1000), color = .{1,1,0,1});
    // render_draw_line(render_position, render_position + (ground_rotation_velocity * render_unit * 1000), color = .{0,0,1,1});
    
    // render_draw_rect(Rectf.{ position = (offset + camera.focus_point) * render_unit - .{1,1}, size = .{3,3} });
}

get_player_collision_rect :: (using player: Player) -> Rectf {
    return .{ 
        position = position - size / 2, 
        size     = size 
    };
}

award_coins :: (using player: *Player, count: int) {
    coins += count;
    if coins == 100 {
        lives += 1;
        coins -= 100;
    }
    temp_lives += 1;
}

render_player_hud :: (using player: *Player, render_unit: float, offset: Vector2) {
    text_position := offset;
    text_size := Vector2.{ 0.5, 0.5 } * render_unit;
    
    render_small_text("GUY", position = text_position, size = text_size);
    
    text_position.y += text_size.y;
    render_small_text("%",
        formatInt(player.coins, minimum_digits = 3),
        position = text_position + .{ text_size.x * 3, 0 },
        size     = text_size,
        align    = 1,
    );
    
    do_area_name, level, area := get_active_level_and_area();
    if do_area_name {
        text_position.y += text_size.y;
        render_small_text("% / %", level.name, area.name,
            position = text_position,
            size     = text_size,
        );
    } else {
        text_position.y += text_size.y;
        render_small_text("Editor Level",
            position = text_position,
            size     = text_size,
        );
    }
    
    // TODO: render coins
    // TODO: render health
}

unload_player_templates :: () {
    for *t: player_templates {
        for *a: t.animations  array_reset(*a.frames);
    }
    array_reset(*player_templates);
}

load_player_templates :: () -> bool {
    if player_templates  unload_player_templates();
    
    ok := LSD.load_and_parse_file("data/player_templates.lsd", #code {
        LSD.register_procedure(*parser.script, "palette", get_color_animation_index);
        LSD.register_procedure(*parser.script, "sound", load_sfx);
        
        LSD.add_data_binding_to_dom(*parser, player_templates, "templates");
    });
    if !ok  return false;
    
    // we have to do some post-processing on physics values to account for framerate
    for *player_templates {
        using it.physics;
        
        ground_friction          = compute_friction(ground_friction);
        stop_friction            = compute_friction(stop_friction);
        air_friction             = compute_friction(air_friction);
        coyote_time              = coyote_time * updates_per_second;
        // gravity                  = (gravity             / (updates_per_second * updates_per_second));
        jump_gravity             = (jump_gravity        / (updates_per_second * updates_per_second));
        hold_gravity             = (hold_gravity        / (updates_per_second * updates_per_second));
        fall_gravity             = (fall_gravity        / (updates_per_second * updates_per_second));
        fastfall_gravity         = (fastfall_gravity    / (updates_per_second * updates_per_second));
        jump_force               = compute_jump_force(jump_height,         jump_gravity);
        jump_release_force       = compute_jump_force(jump_release_height, fall_gravity);
        run_jump_force           = compute_jump_force(run_jump_force,      jump_gravity);
        bounce_force             = compute_jump_force(bounce_force,        fall_gravity);
        // long_jump_force          = compute_jump_force(long_jump_height,    gravity);
        // ledge_jump_force         = compute_jump_force(ledge_jump_height,   gravity);
        // long_jump_speed          = (long_jump_speed     / updates_per_second);
        max_fall_speed           = max_fall_speed       / updates_per_second;
        max_fastfall_speed       = max_fastfall_speed   / updates_per_second;
        run_speed                = run_speed            / updates_per_second;
        fastfall_jerkdown        = fastfall_jerkdown    / updates_per_second;
        swimspeed                = swimspeed            / updates_per_second;
        top_airspeed             = top_airspeed         / updates_per_second;
        
        // acceleration constants given in terms of seconds required to reach full speed, not tiles per second squared
        run_accel                = run_speed  / (run_accel  * updates_per_second);
        air_accel                = run_speed  / (air_accel  * updates_per_second);
        turnaround_boost         = turnaround_boost;
        
        semisolid_drop_time *= updates_per_second;
        
        // ground_friction_slippery = compute_friction(ground_friction_slippery);
        // stop_friction_slippery   = compute_friction(stop_friction_slippery);
        // ground_friction_sticky   = compute_friction(ground_friction_sticky);
        // stop_friction_sticky     = compute_friction(stop_friction_sticky);
        // speed_mod_slippery       = speed_mod_slippery;
        // accel_mod_slippery       = accel_mod_slippery;
        // speed_mod_sticky         = speed_mod_sticky;
        // accel_mod_sticky         = accel_mod_sticky;
    }
    
    // print("player templates: %\n", player_templates);
    
    return true;
}


try_damage_player :: (player: *Player) {
    should_take_damage := is_vulnerable(player);
    if should_take_damage {
        create_player_damage_particles(player.position);
        
        template := get_template(player);
        player.is_dead = 1;
        stop_music();
        play(template.noises.die);
        return;
    }
}


create_player_damage_particles :: (position: Vec2f, particle_count := 8) {
    for 0..particle_count-1 {
        slot := get_next_slot(*get_active_level().particles.front);
        slot.occupied = true;
        
        velocity := Vec2f.{
            0.0035 * (random_get_zero_to_one() - 0.5),
            0.0035 * (random_get_zero_to_one() - 0.5),
        } * updates_per_second.(float);
        
        offset := Vec2f.{
            0.35 * (random_get_zero_to_one() - 0.5),
            0.35 * (random_get_zero_to_one() - 0.5),
        };
        
        active_time_seconds := random_get_within_range(0.2, 0.6);
        active_time_frames  := active_time_seconds * updates_per_second;
        
        scale := random_get_within_range(0.6, 1.2);
        alpha := random_get_within_range(0.8, 1.2);
        
        slot.data = .{
            texture = *particles_texture,
            palette = get_color_animation_index("coins"),
            
            particle_type = .DYNAMIC,
            dynamic = .{
                scale            = .{ scale, scale },
                position         = position + offset, 
                velocity         = velocity,
                acceleration     = -velocity / active_time_frames,
                // angular_velocity = 5 * (random_get_zero_to_one() - 0.5),
                lifetime         = active_time_frames.(s32),
                alpha            = alpha,
                alpha_velocity   = -alpha / (2.0 * active_time_frames),
            }
        };
        
        anim := *slot.animation;
        anim.flags = .LOOP;
        anim.frame_count = 4;
        anim.frames[0] = .{ clip = .{  64, 16, 16, 16 }, duration = active_time_seconds * 0.25 };
        anim.frames[1] = .{ clip = .{  80, 16, 16, 16 }, duration = active_time_seconds * 0.25 };
        anim.frames[2] = .{ clip = .{  96, 16, 16, 16 }, duration = active_time_seconds * 0.25 };
        anim.frames[3] = .{ clip = .{ 112, 16, 16, 16 }, duration = active_time_seconds * 0.25 };
    }
}

do_tilemap_collision :: (tilemap: *Tilemap, player: *Player) {
    using player.collision_data;
    player.collision_data = .{};
    
    position_in_tilemap = get_position_in_tilemap(tilemap, player.position);
    velocity_in_tilemap = player.velocity - tilemap.velocity;
    
    if !broad_phase_collision_check(tilemap, position_in_tilemap, 4)  return;
    
    reset_collision_points(player);
    points := *player.collision_points;
    
    for *points {
        it.point_in_tilemap = position_in_tilemap + it.point_relative_to_origin;
        it.tile_index       = to_Vec2i_floor(it.point_in_tilemap);
        it.tile_ptr         = get_tile(tilemap, it.tile_index);
        if !it.tile_ptr  continue;
        
        it.tile_info = get_tile_info(it.tile_ptr);
        
        // TODO: broken tiles?
        
        if it.tile_info.collision.type == .BLOCK && (it.tile_info.collision.flags & .SOLID) {
            it.had_collision = true;
            had_collision = true;
        }
    }
    
    if !had_collision  return;
    
    apply_ground_velocity := false;
    
    // TODO
    collide_tile :: (tile: *Tile, player: *Player) {
        info := get_tile_info(tile);
        if info.collision.flags & .CRUMBLE {
            if tile.crumble_timer == 0 {
                tile.crumble_timer = (info.crumble_time * window_width).(u16);
            }
        }
    }
    
    get_tile_bounce :: (tile: *Tile, dir: Direction) -> float {
        mod := get_tile_modifier(tile, dir);
        return ifx mod == .BOUNCY then 1.75 else 1.0;
    }
    
    if points.L.had_collision {
        point := *points.L;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            player.position.x += 1 - position_in_tile.x;
            if player.velocity.x < tilemap.velocity.x {
                player.velocity.x = tilemap.velocity.x;
            }
        }
    }
    
    if points.R.had_collision {
        point := *points.R;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            player.position.x -= position_in_tile.x;
            if player.velocity.x > tilemap.velocity.x {
                player.velocity.x = tilemap.velocity.x;
            }
        }
    }
    
    bonk_prevention_fudge_factor := units_per_second(0.5);
    
    if points.U.had_collision {
        point := *points.U;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            player.position.y += 1 - position_in_tile.y;
            if player.velocity.y < tilemap.velocity.y {
                player.velocity.y = tilemap.velocity.y;
            }
        }
    } else {
        if points.UL.had_collision {
            point := *points.UL;
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            if !(point.tile_info.collision.flags & .SEMISOLID) {
                point.direction_out = ifx 1-position_in_tile.x < 1-position_in_tile.y || velocity_in_tilemap.x > bonk_prevention_fudge_factor then .L else .U;
                
                if point.direction_out == {
                  case .U;
                    player.position.y += 1 - position_in_tile.y;
                    if player.velocity.y < tilemap.velocity.y {
                        player.velocity.y = tilemap.velocity.y;
                    }
                  case .L;
                    player.position.x += 1 - position_in_tile.x;
                    if player.velocity.x < tilemap.velocity.x {
                        player.velocity.x = tilemap.velocity.x;
                    }
                }
            }
        }
        if points.UR.had_collision {
            point := *points.UR;
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            if !(point.tile_info.collision.flags & .SEMISOLID) {
                point.direction_out = ifx position_in_tile.x < 1-position_in_tile.y || velocity_in_tilemap.x > bonk_prevention_fudge_factor then .R else .U;
                
                if point.direction_out == {
                  case .U;
                    player.position.y += 1 - position_in_tile.y;
                    if player.velocity.y < tilemap.velocity.y {
                        player.velocity.y = tilemap.velocity.y;
                    }
                  case .R; 
                    player.position.x -= position_in_tile.x;
                    if player.velocity.x > tilemap.velocity.x {
                        player.velocity.x = tilemap.velocity.x;
                    }
                }
            }
        }
    }
    
    push_point_up :: (point: *Tilemap_Collision_Point, position_in_tile: Vec2f) #expand {
        player.position.y -= position_in_tile.y;
        if player.velocity.y > tilemap.velocity.y {
            player.velocity.y = tilemap.velocity.y;
        }
        collide_tile(point.tile_ptr, player);
        player.collision_data.on_ground = true;
        apply_ground_velocity = true;
    }
    
    if points.D.had_collision {
        point := *points.D;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        
        if !(point.tile_info.collision.flags & .SEMISOLID) || (player.semisolid_drop_timer == 0 && max(velocity_in_tilemap.y, 0.2 ) > position_in_tile.y) {
            push_point_up(point, position_in_tile);
        } else print_vars(velocity_in_tilemap.y, position_in_tile.y);
    } else {
        if points.DL.had_collision {
            point := *points.DL;
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            if point.tile_info.collision.flags & .SEMISOLID {
                if player.semisolid_drop_timer == 0 && max(velocity_in_tilemap.y, 0.2) > position_in_tile.y {
                    point.direction_out = .D;
                } else {
                    point.direction_out = .U; // @Hack: not a valid option, so will do nothing below
                    log("a;slkdjfklasjdf");
                }
            }
            else point.direction_out = ifx 1-position_in_tile.x < position_in_tile.y then .L else .D;
            
            if point.direction_out == {
              case .D;
                push_point_up(point, position_in_tile);
              case .L;
                player.position.x += 1 - position_in_tile.x;
                if player.velocity.x < tilemap.velocity.x {
                    player.velocity.x = tilemap.velocity.x;
                }
            }
        }
        if points.DR.had_collision {
            point := *points.DR;
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            if point.tile_info.collision.flags & .SEMISOLID {
                if player.semisolid_drop_timer == 0 && max(velocity_in_tilemap.y, 0.2) > position_in_tile.y {
                    point.direction_out = .D;
                } else {
                    point.direction_out = .U; // @Hack: not a valid option, so will do nothing below
                    log("a;slkdjfklasjdf");
                }
            }
            else point.direction_out = ifx position_in_tile.x < position_in_tile.y then .R else .D;
            
            if point.direction_out == {
              case .D;
                push_point_up(point, position_in_tile);
              case .R; 
                player.position.x -= position_in_tile.x;
                if player.velocity.x > tilemap.velocity.x {
                    player.velocity.x = tilemap.velocity.x;
                }
            }
        }
    }
    
    if apply_ground_velocity {
        player.ground_velocity = tilemap.velocity; // + conveyor_velocity;
    }
}


reset_collision_points :: (using player: *Player) {
    corner_dist :: Vec2f.{ 5.0 / 16.0, 7.0 / 16.0 };
    
    collision_points.U  = .{ point_relative_to_origin = .{ 0, -size.y / 2 } }; 
    collision_points.D  = .{ point_relative_to_origin = .{ 0,  size.y / 2 } }; 
    collision_points.L  = .{ point_relative_to_origin = .{ -size.x / 2, 0 } }; 
    collision_points.R  = .{ point_relative_to_origin = .{  size.x / 2, 0 } }; 
    collision_points.UR = .{ point_relative_to_origin = .{  size.x, -size.y } * corner_dist }; 
    collision_points.DR = .{ point_relative_to_origin = .{  size.x,  size.y } * corner_dist }; 
    collision_points.UL = .{ point_relative_to_origin = .{ -size.x, -size.y } * corner_dist }; 
    collision_points.DL = .{ point_relative_to_origin = .{ -size.x,  size.y } * corner_dist }; 
}