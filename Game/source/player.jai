
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
    
    max_slope_accel_scalar:     float;
    
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
    name:            string;
    character_name:  string;
    powerup_id:      int;
    
    uuid:            u64;
    palette:         int;
    animations:      Player_Animations;
    noises:          Entity_Sounds;
    physics:         Player_Physics;
    collision_size:  Vec2f;
    crouching_collision_size:  Vec2f;
    power_down_id:   int;
    
    Flags :: enum_flags {
        CAN_BREAK_BLOCKS;
    };
    flags: Flags;
}

player_templates: [..] Player_Template;


Player :: struct {
    using #as base: Entity;
    entity_type = .PLAYER;
    
    template_index:         int;
    
    is_dead:                int;
    jump_cooldown:          int;
    ledge_grab:             int;
    last_jump_button_down:  int;
    on_ground:              int; // = counts up on ground (0 +), counts down off ground (-1 -)

    held_entity_handle:     Entity_Handle = .{ -1, -1 };
    pickup_lerp:            float;
    
    // camera stuff
    facing:                 Direction;
    
    run_normal:             Vector2;
    
    animator:               Player_Animator;
    controller_index:       int;
    
    lives: int;
    score: int;
    coins: int;
    
    // debug
    ground_stick_force:         Vector2;
    
    camera: struct {
        focus_point:       Vector2;
        facing_weight:     float;
    }
    
    iframes: int;
    
    State :: enum {
        STANDARD :: 0;
        ENTERING_WARP;
        EXITING_WARP;
    };
    state: State;
    
    // info for non-standard player state
    warp: struct {
        clock:  int;
        handle: Entity_Handle;
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

set_template :: (player: *Player, character_name: string, powerup_id := 0) {
    set_template(player, find_player_template_index(character_name, powerup_id));
}

set_template :: (player: *Player, index: int) {
    if index < 0 || index >= player_templates.count  return;
    template := *player_templates[index];
    player.template_index = index;
    player.palette        = template.palette;
    // player.size           = template.collision_size;
}

get_template :: (player: Player) -> *Player_Template { 
    if player.template_index == -1 return null;
    return *player_templates[player.template_index]; 
}

// NOTE: we get the controller as an array view so that it can be indexed directly and modified. Otherwise, we would need to deref before indexing.
get_controller :: inline(player: Player) -> *Player_Controller {
    return *Game.player_controllers[player.controller_index];
}

find_player_template_index :: (character_name: string, powerup_id := 0) -> int {
    for player_templates
        if it.character_name == character_name 
        && it.powerup_id     == powerup_id
            return it_index;
    log("unable to find player template '%', powerup_id %", character_name, powerup_id);
    log("player_templates:");
    for player_templates  log("% %", it.name, it.powerup_id);
    return -1;
}

init_player :: (player: *Player, template_name := "Mario") {
    defer_restore(*player.position);
    defer_restore(*player.camera);
    defer_restore(*player.lives);
    defer_restore(*player.score);
    defer_restore(*player.coins);
    
    player.* = .{};
    set_template(player, template_name, 1);
}

begin_entering_warp :: (player: *Player, warp: *Warp) {
    player.state = .ENTERING_WARP;
    player.warp = .{
        clock  = (WARP_DOOR_ENTRY_TIME * UPDATES_PER_SECOND).(int),
        handle = warp.handle,
    };
    create_door_entry_particles(player.position);
}

begin_exiting_warp :: (player: *Player, warp: *Warp) {
    player.state = .EXITING_WARP;
    player.position = warp.position;
    snap_player_camera_focus_point(player);
    player.warp = .{
        clock  = (WARP_DOOR_EXIT_TIME * UPDATES_PER_SECOND).(int),
        handle = warp.handle,
    };
}

update_player :: (using player: *Player) {
    level      := context.current_level;
    template   := get_template(player);
    if !template  return;
    
    physics    := *template.physics;
    controller := get_controller(player);
    
    SPEED_EPSILON := 0.1 / UPDATES_PER_SECOND;
    
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
    if iframes       > 0  iframes       -= 1;
    if jump_cooldown > 0  jump_cooldown -= 1;
    
    if is_dead > 0 {
        is_dead += 1;
        if is_dead < (0.5 * UPDATES_PER_SECOND).(int) {
            // set player velocity up, but don't actually move player
            // TODO: calculating this every frame here is dumb, we should do this in some kill_player() proc
            player.velocity.y = -compute_jump_force(3, template.physics.hold_gravity);
            player.velocity.x = 0;
        } else if is_dead > (3.0 * UPDATES_PER_SECOND).(int) && position.y > level.bounds.y + level.bounds.h + 2 {
            player.lives -= 1;
            
            Game.event_flags |= .SCENE_TRANSITION;
            Game.scene_transition = .{ 
                src_scene = .LEVEL, 
                dst_scene = .LEVEL, 
                clock     = (Scene_Transition.TRANSITION_FADE_TIME * UPDATES_PER_SECOND).(int)
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
                player_ground_stick_thresh_lower := 1.0 / UPDATES_PER_SECOND;
                player_ground_stick_thresh_upper := 2.0 / UPDATES_PER_SECOND;
                
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
            jump_vec   : Vector2;
            jump_force := 1.0;
            // TODO:
            // if ground_modifier == TILE_MOD_STICKY { ... } else
            jump_vec = .{0,-1};
            jump_vec *= jump_force * physics.jump_force;
            
            // negate x component of jump if we are moving up a slope
            // so we will get an x boost going down, but not lose x going up
            if (controller.LEFT .state & .PRESSED) && jump_vec.x > 0 
            || (controller.RIGHT.state & .PRESSED) && jump_vec.x < 0 {
                jump_vec.x = 0;
            }
            
            if controller.JUMP.state & .PRESSED {
                if jump_cooldown == 0 {
                    do_normal_jump := (on_ground >= 0 && (last_jump_button_down < physics.coyote_time.(int) /*|| ground_modifier == TILE_MOD_BOUNCY*/));
                    do_coyote_jump := (on_ground <  0 && -on_ground < physics.coyote_time.(int) && (controller.JUMP.state == .PRESSED) /*&& ground_modifier != TILE_MOD_BOUNCY*/);
                    
                    if do_normal_jump || do_coyote_jump {
                        if velocity.y > 0 {
                            velocity.y *= 1.0 - jump_force;
                        } else {
                            velocity.y *= 0.5;
                        }
                        velocity.x += jump_vec.x;
                        velocity.y = jump_vec.y + (ground_velocity.y + ground_rotation_velocity.y) * 0.75;
                        
                        do_blend_y_vel = false;
                        ground_velocity *= 0.75;
                        jump_cooldown = physics.coyote_time.(int);
                        // ground_modifier = TILE_MOD_NONE;
                        
                        play(*template.noises.jump);
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
                }
                else {
                    if velocity.y < 0 then velocity.y = 0;
                    velocity.y += physics.fastfall_jerkdown;
                }
            }
            gravity = physics.fastfall_gravity;
            max_fall_speed = physics.max_fastfall_speed;
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
    
    
    // TODO: should not be necessary
    player.size = template.collision_size;
    
    on_ground_this_frame := false;
    
    if should_do_tilemap_collision {
        collision_data.bounce_factor       = .{ 1, 1 };
        collision_data.broad_phase_margin  = 4;
        // collision_data.can_stand_on_slopes = true;
        
        vel_before := velocity;
        
        for *tilemap, tilemap_index: level.tilemaps {
            collision_data.center_point        = player.position;
            collision_data.velocity            = player.velocity;
            collision_data.collision_points    = get_collision_points(player);
            
            if get_tilemap_collision_data(tilemap, *collision_data) {
                handle_collision_response(tilemap, *collision_data, player);
                
                if collision_data.on_ground {
                    on_ground_this_frame = true;
                }
                
                // // collect coins
                // for collision_data.collision_points {
                //     index := to_Vec2i_floor(it.point_in_tilemap);
                //     tile  := get_tile(tilemap, index);
                //     if tile == null  continue;
                //     if get_tile_info(tile.*).collision.type == .COIN {
                //         award_coins(player, 1);
                //         remove_tile(tile);
                //     }
                // }
                
                // TODO: this should be returned in tilemap_collision_results
                relative_velocity := vel_before - (tilemap.velocity /* + velocity from rotation at point of head? */);
                
                if relative_velocity.y < 0 {
                    for dir: Direction.[ .U, .UL, .UR ] {
                        point := collision_data.collision_points[dir];
                        if point.had_collision {
                            bump_tile(tilemap_index, point.tile_index, ifx template.flags & .CAN_BREAK_BLOCKS then .BIG_PLUMBER else .SMALL_PLUMBER, point.direction_out, relative_velocity);
                        }
                    }
                }
                
                // for dir: Direction.[ .D, .DL, .DR ] {
                //     point := collision_data.collision_points[dir];
                //     if point.had_collision && tile_is_bumping(point.tile_ptr) {
                //         velocity.y -= 0.15;
                //         break;
                //     }
                //     if length(point.velocity_adjust) > (0.0005 * UPDATES_PER_SECOND) { 
                //         play(*template.noises.land);
                //     }
                // }
            }
            
            // print_vars(collision_data.center_point_in_tilemap);
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
        if on_ground > xx (0.0 * UPDATES_PER_SECOND) {
            MOVE_SPEED := 1.0 / (1.0 * UPDATES_PER_SECOND);
            
            if      (facing == .L && camera.facing_weight > -1.0) camera.facing_weight -= MOVE_SPEED; // left
            else if (facing == .R && camera.facing_weight <  1.0) camera.facing_weight += MOVE_SPEED; // right
            else { // neutral
                if      (camera.facing_weight > 0) camera.facing_weight -= MOVE_SPEED;
                else if (camera.facing_weight < 0) camera.facing_weight += MOVE_SPEED;
            }
        }
        
        focus_point.x += camera.facing_weight * camera_constants.focus_distance * run_normal.x;
        focus_point.y += camera.facing_weight * camera_constants.focus_distance * run_normal.y;
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
                    pickup_lerp = min(pickup_lerp + 7.0/UPDATES_PER_SECOND, 1);
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
            else if abs(velocity_relative_to_ground.x) < 0.75 / UPDATES_PER_SECOND {
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
    //     if (walk_noise_accumulator > 70.0 / UPDATES_PER_SECOND) {
    //         walk_noise_accumulator = 0;
    //         play(*template.noises.land);
    //     }
    // }
    
    // TODO: maybe the animation for player walking should just be beased on how long they've been holding the button... that way regardless of the actual surface they're walking on it shows something like the effort the player character is exerting to walk?
    // TODO: velocity relative to ground is also not quite right here, since what we really want is velocity along the surface player is walking on
    //       which would be like magnitude of player velocity_relative_to_ground along normal of (last_ground_angle + 90)
    step := (ifx anim_state == .WALK then abs(velocity_relative_to_ground.x) * UPDATES_PER_SECOND else 1.0);
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
    
    self_offset     := Vec2f.{ 0, size.y/2 } - (clip.size * .{ 0.5, 1.0 } / TILE_TEXTURE_SIZE);
    render_position := (position + offset + self_offset) * render_unit;
    render_size     := clip.size * render_unit / TILE_TEXTURE_SIZE;
    
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
    // render_draw_line(render_position, render_position + (ground_stick_force       * render_unit * 1000), color = .{1,0,1,1});
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
    score += 100;
}

render_player_hud :: (using player: *Player, render_unit: float, offset: Vector2) {
    text_position := offset;
    text_size := Vector2.{ 0.5, 0.5 } * render_unit;
    
    render_small_text("GUY", position = text_position, size = text_size);
    
    text_position.y += text_size.y;
    render_small_text("%",
        formatInt(player.score, minimum_digits = 6),
        position = text_position + .{ text_size.x * 6, 0 },
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
    
    ok := LSD.load_and_parse_file("data/player_templates.gon", #code {
        LSD.register_procedure(*parser.script, "palette", #procedure_of_call get_palette_index(""));
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
        coyote_time              = coyote_time * UPDATES_PER_SECOND;
        // gravity                  = (gravity             / (UPDATES_PER_SECOND * UPDATES_PER_SECOND));
        jump_gravity             = (jump_gravity        / (UPDATES_PER_SECOND * UPDATES_PER_SECOND));
        hold_gravity             = (hold_gravity        / (UPDATES_PER_SECOND * UPDATES_PER_SECOND));
        fall_gravity             = (fall_gravity        / (UPDATES_PER_SECOND * UPDATES_PER_SECOND));
        fastfall_gravity         = (fastfall_gravity    / (UPDATES_PER_SECOND * UPDATES_PER_SECOND));
        jump_force               = compute_jump_force(jump_height,         jump_gravity);
        jump_release_force       = compute_jump_force(jump_release_height, fall_gravity);
        run_jump_force           = compute_jump_force(run_jump_force,      jump_gravity);
        bounce_force             = compute_jump_force(bounce_force,        fall_gravity);
        // long_jump_force          = compute_jump_force(long_jump_height,    gravity);
        // ledge_jump_force         = compute_jump_force(ledge_jump_height,   gravity);
        // long_jump_speed          = (long_jump_speed     / UPDATES_PER_SECOND);
        max_fall_speed           = max_fall_speed       / UPDATES_PER_SECOND;
        max_fastfall_speed       = max_fastfall_speed   / UPDATES_PER_SECOND;
        run_speed                = run_speed            / UPDATES_PER_SECOND;
        fastfall_jerkdown        = fastfall_jerkdown    / UPDATES_PER_SECOND;
        swimspeed                = swimspeed            / UPDATES_PER_SECOND;
        top_airspeed             = top_airspeed         / UPDATES_PER_SECOND;
        
        // acceleration constants given in terms of seconds required to reach full speed, not tiles per second squared
        run_accel                = run_speed  / (run_accel  * UPDATES_PER_SECOND);
        air_accel                = run_speed  / (air_accel  * UPDATES_PER_SECOND);
        turnaround_boost         = turnaround_boost;
        
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
        } * UPDATES_PER_SECOND.(float);
        
        offset := Vec2f.{
            0.35 * (random_get_zero_to_one() - 0.5),
            0.35 * (random_get_zero_to_one() - 0.5),
        };
        
        active_time_seconds := random_get_within_range(0.2, 0.6);
        active_time_frames  := active_time_seconds * UPDATES_PER_SECOND;
        
        scale := random_get_within_range(0.6, 1.2);
        alpha := random_get_within_range(0.8, 1.2);
        
        slot.data = .{
            texture = *particles_texture,
            palette = get_palette_index("coins"),
            
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

handle_collision_response :: (tilemap: *Tilemap, player: *Player) {
    using player.collision_data; 
    
    apply_ground_velocity := false;
    
    // TODO
    entity_collide_tile :: (tile: *Tile, player: *Entity) {
        info := get_tile_info(tile);
        if info.collision.flags & .CRUMBLE {
            if tile.crumble_timer == 0 {
                tile.crumble_timer = (info.crumble_time * FRAMES_PER_SECOND).(u16);
            }
        }
    }
    
    get_tile_bounce :: (tile: *Tile, dir: Direction) -> float {
        mod := get_tile_modifier(tile, dir);
        return ifx mod == .BOUNCY then 1.75 else 1.0;
    }
    
    if collision_points[Direction.L].had_collision {
        point := *collision_points[Direction.L];
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        player.position.x += 1 - position_in_tile.x;
        if player.velocity.x < tilemap.velocity.x {
            player.velocity.x = tilemap.velocity.x;
        }
    }
    
    if collision_points[Direction.R].had_collision {
        point := *collision_points[Direction.R];
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        player.position.x -= position_in_tile.x;
        if player.velocity.x > tilemap.velocity.x {
            player.velocity.x = tilemap.velocity.x;
        }
    }
    
    BONK_PREVENTION_FUDGE_FACTOR := 0.5 / UPDATES_PER_SECOND;
    
    if collision_points[Direction.U].had_collision {
        point := *collision_points[Direction.U];
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        player.position.y += 1 - position_in_tile.y;
        if player.velocity.y < tilemap.velocity.y {
            player.velocity.y = tilemap.velocity.y;
        }
    } else {
        if collision_points[Direction.UL].had_collision {
            point := *collision_points[Direction.UL];
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            point.direction_out = ifx 1-position_in_tile.x < 1-position_in_tile.y || velocity_in_tilemap.x > BONK_PREVENTION_FUDGE_FACTOR then .L else .U;
            
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
        if collision_points[Direction.UR].had_collision {
            point := *collision_points[Direction.UR];
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            // determine if we push out as .U or .R
            // TODO: put velocity in terms of updates/second
            point.direction_out = ifx position_in_tile.x < 1-position_in_tile.y || velocity_in_tilemap.x > BONK_PREVENTION_FUDGE_FACTOR then .R else .U;
            
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
    
    if collision_points[Direction.D].had_collision {
        point := *collision_points[Direction.D];
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        player.position.y -= position_in_tile.y;
        if player.velocity.y > tilemap.velocity.y {
            player.velocity.y = tilemap.velocity.y;
        }
        entity_collide_tile(point.tile_ptr, player);
        on_ground = true;
        apply_ground_velocity = true;
    } else {
        if collision_points[Direction.DL].had_collision {
            point := *collision_points[Direction.DL];
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            // determine if we push out as .D or .L
            // TODO: put velocity in terms of updates/second
            point.direction_out = ifx 1-position_in_tile.x < position_in_tile.y then .L else .D;
            
            if point.direction_out == {
              case .D;
                player.position.y -= position_in_tile.y;
                if player.velocity.y > tilemap.velocity.y {
                    player.velocity.y = tilemap.velocity.y;
                }
                entity_collide_tile(point.tile_ptr, player);
                on_ground = true;
                apply_ground_velocity = true;
              case .L;
                player.position.x += 1 - position_in_tile.x;
                if player.velocity.x < tilemap.velocity.x {
                    player.velocity.x = tilemap.velocity.x;
                }
            }
        }
        if collision_points[Direction.DR].had_collision {
            point := *collision_points[Direction.DR];
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            // determine if we push out as .D or .R
            // TODO: put velocity in terms of updates/second
            point.direction_out = ifx position_in_tile.x < position_in_tile.y then .R else .D;
            
            if point.direction_out == {
              case .D;
                player.position.y -= position_in_tile.y;
                if player.velocity.y > tilemap.velocity.y {
                    player.velocity.y = tilemap.velocity.y;
                }
                entity_collide_tile(point.tile_ptr, player);
                on_ground = true;
                apply_ground_velocity = true;
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
