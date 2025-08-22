
#import "Random";

Enemy :: struct {
    using #as base: Entity;
    
    template_index:         int;
    flags:                  Enemy_Flags;
    animator:               Enemy_Animator;
    
    walk_direction:         Direction;
    player_ignore_clock:    int;
    
    // used to keep hammer bro types within a set area
    // could also be used to reset entities that wander off screen without being killed, if we wanted to do that
    init_position:          Vector2;
    jump_clock:             int;
    
    // TODO: factor this stuff as collision points
    // collision probing for enemies that don't want to walk off ledges
    ground_found_left  := false;
    ground_found_right := false;
    left\_ground_probe_offset: Vector2;
    right_ground_probe_offset: Vector2;
}

Enemy_Flags :: enum_flags {
    AWAKE;
    DEAD;
    
    NO_COLLIDE_TILEMAP;
    NO_COLLIDE_PLAYER;
    
    PLAYER_STANDING_ON;
};

Enemy_Template :: struct {
    name:           string;
    uuid:           u64;
    palette:        int;
    animations:     Enemy_Animations;
    physics:        Enemy_Physics;
    noises:         Entity_Sounds;
    
    // defines a broad general movement type, mutually exclusive
    // particulars of movement style may be modified by flags
    // movement_style: Movement_Style;
    // Movement_Style :: enum { 
    //     NONE   :: 0;
        
    //     // currently same as .NONE, but here to signal intent
    //     // enemy positions can be set 
    //     SCRIPT :: NONE;
        
    //     // move left and right, turning around when hitting a wall
    //     // if flags & DONT_WALK_OFF_LEDGES then turns around at ledges also
    //     // if flags & CHASE_PLAYER then turns around to follow player
    //     WALK; 
        
    //     // floats around, bouncing off walls
    //     // if flags & CHASE_PLAYER then turns around at ledges also
    //     FLOAT;
    // };
    
    collision_type: Collision_Type;
    Collision_Type :: enum {
        SOLID;
        HURTY;
        BOUNCY;
        TILE;       // can do collision for any tile template
        
        // extra special
        LIFE;
    };
    
    // for now, we presume this is always the same.
    // if need be in the future, we can probably just put the collision data in the animation
    collision_size:     Vector2;
    collision_offset:   Vector2;
    
    
    flags: Flags;
    Flags :: enum_flags {
        DONT_WALK_OFF_LEDGES;
        STAY_FACING_PLAYER;
        CHASE_PLAYER;
        MATCH_PLAYER_JUMP;
        
        // collision flags
        NO_COLLIDE_TILEMAP;
    }
}

/*
    Enemy Movement Notes
    
    I am thinking that perhaps all the movmeent styles I wantt o implement can actaulyl be implemented purely by changing the enemy physics values, 
    even though at first the movement styles may seem mutually exclusive in some regards.
    
    Movement styles:
        walkers
            move left/right, turn around when hitting a wall or (optionally) when hitting a ledge
            also optionally follow the player
            also optionally move faster when player is on the same ground level 
        floaters
            float left/right or up/down, turn around when hitting a wall
            or float towards player like a Boo,
            or float around diagonally, bouncing off all surfaces
        jumpers
            basically act like tein frog guys
            or, have ones that act like the jumpy mouse dudes from mario 3d world (jump when player jumps)
            may want dudes who both walk and jump
        bouncers
            basically just floaters with gravity also
        pathers
            basically floaters that are controlled by script rather than running their own movement logic internally
            can be used to get more complex patterns like circles and figure eights
*/

Enemy_Physics :: struct {
    walk_speed:         float;
    walk_accel:         float;
    
    run_speed:          float;
    run_accel:          float;
    
    air_speed:          float;
    air_accel:          float;
    
    ground_friction:    float;
    stop\ _friction:    float;
    air\  _friction:    float;
    
    max_air_speed:      float;
    
    gravity:            float;
    max_fall_speed:     float;
}

default_enemy_physics: Enemy_Physics;

Enemy_Animation_States :: enum {
    WALK;
    JUMP;
    FALL;
    THROW;
    DEAD;
}

Enemy_Animations :: Enumerated_Array(Enemy_Animation_States, Simple_Animation(0));
Enemy_Animator   :: Simple_Animator(Enemy_Animation_States);

enemy_templates: [..] Enemy_Template;

find_enemy_template_by_name :: (name: string) -> *Enemy_Template {
    for *enemy_templates
        if it.name == name  return it;
    return null;
}

find_enemy_template_by_uuid :: (uuid: u64) -> *Enemy_Template {
    for *enemy_templates 
        if it.uuid == uuid  return it;
    return null;
}


update_enemy :: (using enemy: *Enemy) {
    level    := context.current_level;
    template := *enemy_templates[enemy.template_index];
    physics  := *template.physics;
    
    SPEED_EPSILON := units_per_second(0.1);
    
    if position_prev == .{}  init_position = position; // this is very dumb, but maybe works in practice?
    
    position_prev = position;
    
    // TODO: should only have to set in init
    enemy.size = template.collision_size;
    gravity_angle = 90;
    
    
    // wake up enemies when they come on screen
    // once they're awake they'll always update
    if is_point_within_frect(position, get_camera_visible_rect(.{ 4, 4 })) {
        flags |= .AWAKE;
    }
    if !(flags & .AWAKE)  return;
    
    // check if the enemy has fallen out of the level
    if position.y > level.bounds.y + level.bounds.h + 2 {
        entity_flags |= .REMOVE_ME;
        return;
    }
    
    velocity_relative_to_ground := velocity - (ground_velocity + ground_rotation_velocity);
    
    flags &= ~.NO_COLLIDE_PLAYER; // this gets reset every frame
    
    should_do_movement      := true;
    should_collide_tilemap  := true;
    should_collide_entities := true;
    
    if .NO_COLLIDE_TILEMAP & flags 
    || .NO_COLLIDE_TILEMAP & template.flags {
        should_collide_tilemap = false;
    }
    
    if .HELD & entity_flags {
        flags |= .NO_COLLIDE_PLAYER;
        should_collide_tilemap  = false;
        should_collide_entities = false;
        should_do_movement      = false;
    }
    
    // prevent enemy from interacting with player immediately after being thrown
    if ticks_since_thrown < (0.25 * UPDATES_PER_SECOND).(int) then flags |= .NO_COLLIDE_PLAYER;
    ticks_since_thrown += 1;
    
    // @Hack barrel is always in thrown state so it will rotate. we should refactor this whole file tbh
    // if template.movement_style == .BARREL {
    //     entity_flags |= .THROWN;
    // }
    
    if !(.HELD & entity_flags) && (.THROWN & entity_flags) {
        // if template.flags & .ROTATE_WHEN_THROWN {
        //     if (template.flags & .MUST_RECOVER_WHEN_THROWN) && abs(velocity_relative_to_ground.x) < units_per_second(1) && (.ON_GROUND & entity_flags) {
        //         rotation = fmod_cycling(rotation, 2 * PI);
        //         if rotation < PI
        //             then rotation -= PI/180;
        //             else rotation += PI/180;
                
        //         if abs(fmod_cycling(rotation, 2 * PI)) < 2 * PI / 180 {
        //             entity_flags &= ~.THROWN;
        //             rotation = 0;
        //             walk_direction = ifx velocity.x < 0 then .L else .R;
        //         }
        //     } else {
        //         rotation += 60 * velocity.x * (PI / 180);
        //     }
        // }
    }
    
    if .DEAD & flags {
        flags |= .NO_COLLIDE_PLAYER;
        should_do_movement      = false;
        should_collide_entities = false;
        if .STOPPED & animator.flags {
            entity_flags |= .REMOVE_ME;
            return;
        }
    }
    
    player_ignore_clock = max(player_ignore_clock - 1, 0);
    
    
    
    // ===== Phsyics and Movement =====
    
    // apply ground rotation velocity and ground stick force
    if entity_flags & .ON_GROUND {
        position += ground_rotation_velocity;
        
        ground_stick_force := rotate_degrees(.{ -units_per_second(0.3), 0 }, last_ground_angle);
        position += ground_stick_force;
    }
    
    // determine desired direction of movement
    left\  _pressed := walk_direction == .L;
    right\ _pressed := walk_direction == .R;
    neither_pressed := !(left_pressed || right_pressed);
    
    top_speed := physics.walk_speed;
    accel     := physics.walk_accel;

    if entity_flags & .THROWN {
        // if template.flags & .MUST_RECOVER_WHEN_THROWN {
        //     top_speed = 0; // slow the entity down more?
        // }
    }
    
    sliding := false;
    if sliding then entity_flags |= .SLIDING;
    
    if entity_flags & .ON_GROUND {
        ground_friction := physics.ground_friction;
        stop_friction   := physics.stop_friction;
        
        applied_friction := 1.0;
        
        // whether player can stick to moving ground well should also depend on absolute speed
        // TODO: move these to player physics file
        ground_stick_thresh_lower := units_per_second(1);
        ground_stick_thresh_upper := units_per_second(2);
        
        if !(entity_flags & .THROWN) && (neither_pressed || (right_pressed && velocity_relative_to_ground.x < 0) || (left_pressed && velocity_relative_to_ground.x > 0)) {
            relative_ground_speed_difference := abs(velocity_relative_to_ground.x);
            if relative_ground_speed_difference < ground_stick_thresh_lower {
                applied_friction = 0;
            } else {
                actual_stop_friction := stop_friction;
                if relative_ground_speed_difference < ground_stick_thresh_upper {
                    lerp_t := clamp(delerp(ground_stick_thresh_lower, ground_stick_thresh_upper, relative_ground_speed_difference), 0, 1);
                    actual_stop_friction = lerp(0, stop_friction, lerp_t).(float);
                }
                applied_friction = actual_stop_friction;
            }
        }
        if abs(velocity_relative_to_ground.x) > top_speed {
            applied_friction = stop_friction;
        }
        
        velocity.x = lerp(ground_velocity.x, velocity.x, applied_friction);
    }
    else {
        // air friction and accel
        if abs(velocity.x) > physics.max_air_speed {
            velocity.x *= physics.air_friction;
        }
        // if ((right_pressed && velocity.x < 0)
        //  || (left\_pressed && velocity.x > 0)) {
        //     accel *= physics.turnaround_boost;
        // }
    }
    
    if should_do_movement {
        // if template.movement_style == .GOOMBA {
            // if walk dir is not valid and enemy is on the ground, 
            // then pick the direction to walk based on current velocity
            // this behaviour is used intentionally when items/enemies pop out of item blocks
            if walk_direction != .L && walk_direction != .R {
                if .ON_GROUND & entity_flags {
                    walk_direction = ifx velocity.x > 0 then .R else .L;
                }
            }
            
            if !(.THROWN & entity_flags) && (.ON_GROUND & entity_flags) {
                applicable_accel: float;
                if walk_direction == {
                  case .R; 
                    applicable_accel = clamp(top_speed - velocity_relative_to_ground.x, 0, accel);
                  case .L; 
                    applicable_accel = clamp(-top_speed - velocity_relative_to_ground.x, -accel, 0);
                }
                velocity.x += applicable_accel;
            }
        // }
    }
    
    // applied_gravity := ifx (entity_flags & .ON_GROUND)
    //     then physics.jump_gravity
    //     else physics.hold_gravity;
    applied_gravity := physics.gravity;
    velocity.y = min(physics.max_fall_speed, velocity.y + applied_gravity);
    
    
    position += velocity;
    
    
    
    // ===== Collision =====
    
    before := enemy.velocity;
    do_log_vel := false;
    
    flags &= ~(.PLAYER_STANDING_ON);
    entity_flags &= ~(.ON_GROUND);
    
    ground_found_left  = false;
    ground_found_right = false;
    left\_ground_probe_offset = Vector2.{ -enemy.size.x * 0.5, enemy.size.y * 1.5 };
    right_ground_probe_offset = Vector2.{  enemy.size.x * 0.5, enemy.size.y * 1.5 };

    dbg_collision_mask = xx 0;
    
    if should_collide_tilemap {
        collision_data.bounce_factor       = .{ 1, 1 };
        collision_data.broad_phase_margin  = 4;
        // collision_data.can_stand_on_slopes = true;
        
        if entity_flags & .THROWN {
            collision_data.bounce_factor = .{ 1.5, 1.5 };
        }

        for *tilemap, tilemap_index: level.tilemaps {
            collision_data.center_point        = enemy.position;
            collision_data.velocity            = enemy.velocity;
            collision_data.collision_points    = get_collision_points(enemy);
            
            if get_tilemap_collision_data(tilemap, *collision_data) {
                handle_collision_response(tilemap, *collision_data, enemy);
                
                if collision_data.on_ground {
                    entity_flags |= .ON_GROUND;
                    // new_ground_angle = collision_data.ground_angle;
                }
                if collision_points[Direction.L].had_collision { 
                    walk_direction = .R;
                }
                if collision_points[Direction.R].had_collision { 
                    walk_direction = .L;
                }
                
                if length(collision_data.velocity_adjust) > units_per_second(5) { 
                    play(ifx entity_flags & .THROWN
                        then *template.noises.bounce 
                        else *template.noises.land);
                }
                
                // if (.DONT_WALK_OFF_LEDGES & template.flags) {
                //     entity_velocity_local := enemy.velocity - tilemap.velocity;
                    
                //     entity_position_prev_local := get_position_in_tilemap(tilemap, enemy.position_prev);
                //     entity_position_local      := get_position_in_tilemap(tilemap, enemy.position);
                    
                //     gravity_vec       := unit_vector_given_angle_degrees(gravity_angle);
                //     gravity_vec_local := gravity_vec;
                    
                //     // TODO: this loop is just a bit of a hack to double our probes by moving them out a bit further on the x axis
                //     // for 0..1 {
                //     //     left\_ground_probe := Tilemap_Collision_Point.{ point_relative_to_origin = left\_ground_probe_offset };
                //     //     right_ground_probe := Tilemap_Collision_Point.{ point_relative_to_origin = right_ground_probe_offset };
                        
                //     //     if it == 1 {
                //     //         left\_ground_probe.point_relative_to_origin.x *= 1.5;
                //     //         right_ground_probe.point_relative_to_origin.x *= 1.5;
                //     //     }
                        
                //     //     // for (*Tilemap_Collision_Point.[ *left_ground_probe, *right_ground_probe ]) {
                //     //     //     it.point_in_tilemap = get_position_in_tilemap(tilemap, enemy.position + it.point_relative_to_origin);
                //     //     //     it.tile_index, it.tile_intersect, it.had_collision = cast_ray_to_first_solid_tile(tilemap, it.point_in_tilemap - gravity_vec_local * 2, it.point_in_tilemap, gravity_vec_local * 2);
                //     //     // }
                        
                //     //     ground_found_left  ||= left\_ground_probe.had_collision;
                //     //     ground_found_right ||= right_ground_probe.had_collision;
                //     // }
                // }
                
                // for dir: Direction.[ .D, .DL, .DR ] {
                //     point := collision_points[dir];
                //     if point.had_collision && tile_is_bumping(point.tile_ptr) {
                //         vec_out := unit_vector_given_angle(collision_data.surface_angles[point.direction_out] * PI / 180);
                //         vel_adj := vec_out * units_per_second(10);
                //         enemy.velocity += vel_adj;
                //         entity_flags |= .THROWN;
                //         do_log_vel = true;
                //         break;
                //     }
                // }
                // dbg_collision_mask |= collision_mask;
            }
        }
        
        if (.DONT_WALK_OFF_LEDGES & template.flags) && (entity_flags & .ON_GROUND) {
            if !(ground_found_left  /*&& collision_points[Direction.DL].had_collision*/) then walk_direction = .R;
            if !(ground_found_right /*&& collision_points[Direction.DR].had_collision*/) then walk_direction = .L;
        }
    }
    
    if should_collide_entities {
        // NOTE: add all pre-conditions here so that we don't bother to do the collision test unless there is some reason to.
        is_thrown := (enemy.entity_flags & .THROWN).(bool);
        
        really_should_collide_entities := is_thrown;
        if really_should_collide_entities {
            // collision with other entities (do this in its own update loop? maybe later)
            for *level.entities.slots {
                if enemy.(*void) == it.(*void) then continue;
                
                other := it.(*Entity);
                
                enemy_rect := get_collision_rect(enemy);
                other_rect := get_collision_rect(other);
                if aabb_frect(enemy_rect, other_rect) {
                    if is_thrown {
                        // TODO: the amount of bounce velocity we impart when a thrown enemy hits another enemy and kills it should be configurable
                        //       also, maybe consider absolute speed as well as relative speed?
                        relative_speed := enemy.velocity - other.velocity;
                        if length_greater_than(relative_speed, units_per_second(5)) {
                            if handle_entity_collision(other, enemy, .THROWN) {
                                other.velocity.y = units_per_second(-10);
                            }
                            
                            other_is_thrown := (other.entity_flags & .THROWN).(bool);
                            if other_is_thrown && handle_entity_collision(enemy, other, .THROWN) {
                                enemy.velocity.y = units_per_second(-10);
                            }
                        }
                    }
                }
            }
        }
    }
    
    return;
}

render_enemy :: (using enemy: *Enemy, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    if enemy.template_index < 0 || enemy.template_index > enemy_templates.count  return;
    template := *enemy_templates[enemy.template_index];
    level := context.current_level;
    
    update_enemy_animator(enemy);

    current_animation := *template.animations[animator.state];
    if !current_animation.frames  return;
    
    current_frame := *current_animation.frames[animator.current];
    
    
    flip := current_frame.flip;
    
    if .STAY_FACING_PLAYER & template.flags {
        if level.player.position.x > position.x 
            then flip |=  .HORIZONTAL;
            else flip &= ~.HORIZONTAL;
    }
    else if walk_direction == .R then flip ^= .HORIZONTAL; 
    
    
    clip := current_frame.clip;
    
    render_position := (position + current_frame.offset + offset) * render_unit;
    render_size := to_Vector2(clip.size) / 16.0 * render_unit;
    
    render_draw_quad(
        texture  = *entities_texture,
        color    = .{ 1, 1, 1, alpha_mod },
        position = render_position,
        size     = render_size,
        clip     = *rect_to_frect(current_frame.clip),
        flip     = flip,
        palette  = enemy.palette,
        rotate   = rotation
    );
    
    render_position = (position + offset) * render_unit;
    // render_draw_line(render_position, render_position + (last_velocity_adjust * render_unit * 1000), color = .{1,1,0,1});
    // draw_collision_points(collision_data, render_position, render_unit, dbg_collision_mask);
    // if (entity_flags & .ON_GROUND) && (.DONT_WALK_OFF_LEDGES & template.flags) {
    //     render_draw_line(render_position + (left\_ground_probe_offset - .{ 0, 2 }) * render_unit, render_position + (left\_ground_probe_offset) * render_unit, color = ifx ground_found_left  then Color4.{0,1,0,1} else .{1,0,0,1});
    //     render_draw_line(render_position + (right_ground_probe_offset - .{ 0, 2 }) * render_unit, render_position + (right_ground_probe_offset) * render_unit, color = ifx ground_found_right then Color4.{0,1,0,1} else .{1,0,0,1});
    // }
}

update_enemy_animator :: (using enemy: *Enemy) {
    if template_index < 0 || template_index > enemy_templates.count  return;
    template := *enemy_templates[template_index];
    
    update_enemy_animation_state(enemy);
    step_animator(*animator, template.animations.data, Game.render_delta_time);
}

update_enemy_animation_state :: (using enemy: *Enemy) {
    template := *enemy_templates[enemy.template_index];
    
    if .DEAD & flags {
        set_animation(*animator, .DEAD);
    }
    else {
        // if throw.clock == 10 {
        //     set_animation(*animator, .THROW);
        // }
        if animator.state != .THROW || (animator.flags & .STOPPED) {
            if !(.ON_GROUND & entity_flags) {
                maybe_set_animation(*animator, ifx velocity.x < 0 then .JUMP else .FALL, template.animations.data);
            } 
            else {
                set_animation(*animator, .WALK);
            }
        } 
    }
}

get_collision_rect :: (using enemy: *Enemy) -> Rectf {
    if enemy.template_index < 0 || enemy.template_index > enemy_templates.count  return .{};
    template := *enemy_templates[enemy.template_index];
    return .{
        x = (position.x + template.collision_offset.x),
        y = (position.y + template.collision_offset.y),
        w = (template.collision_size.x),
        h = (template.collision_size.y),
    };
}

// not used in render_enemy, because we need the other info in current_frame
// will probably use this for the preview in editor
get_enemy_render_clip :: (using enemy: Enemy) -> Rect {
    if enemy.template_index < 0 || enemy.template_index > enemy_templates.count  return .{};
    template := *enemy_templates[enemy.template_index];
    current_animation := *template.animations[animator.state];
    current_frame     := *current_animation.frames[animator.current];
    return current_frame.clip;
}

get_enemy_template_icon_clip :: (using template: Enemy_Template, crop_x: int, crop_y: int) -> Rect {
    walk_animation := template.animations[Enemy_Animation_States.WALK];
    if walk_animation.frames.count == 0  return .{};
    clip := walk_animation.frames[0].clip;
    clip.w = min(crop_x, clip.w).(s32);
    clip.h = min(crop_y, clip.h).(s32);
    return clip;
}

init_enemy :: (enemy: *Enemy, template_index: int, walk_direction: Direction = .L) {
    enemy.* = .{};
    enemy.entity_type    = .ENEMY;
    enemy.template_index = template_index;
    enemy.walk_direction = walk_direction;
    enemy.animator.state = .WALK;
    
    template := *enemy_templates[template_index];
    enemy.palette = template.palette;
    
    enemy.size = template.collision_size;
    enemy.gravity_angle = 90;
}

handle_enemy_collision :: (enemy: *Enemy, other: *Entity, collision_type: Entity_Collision_Type) -> bool {
    template := *enemy_templates[enemy.template_index];
    
    if collision_type == {
      case .THROWN;
        if .DEAD             & enemy.flags     return false;
        create_player_damage_particles(enemy.position, 4);
        kill_enemy(enemy);
        enemy.velocity.y = units_per_second(-10); // TODO: configure amount in template
        return true;
        
      case .FIREBALL;
        if .DEAD           & enemy.flags           return false;
        create_player_damage_particles(enemy.position, 4);
        kill_enemy(enemy);
        enemy.velocity.y = units_per_second(-10); // TODO: configure amount in template
        return true;
    }
    
    return false;
}

kill_enemy :: (using enemy: *Enemy) {
    template := *enemy_templates[template_index];
    flags |= .DEAD | .NO_COLLIDE_TILEMAP;
    entity_flags &= ~.HELD;
    entity_flags |= .THROWN;
    play(template.noises.hit);
}

enemy_collide_plumber :: (using enemy: *Enemy, player: *Player, entity_index: int) {
    if enemy.flags & .NO_COLLIDE_PLAYER then return;
    
    template := *enemy_templates[enemy.template_index];
    
    p_rect := get_collision_rect(player.*);
    e_rect := get_collision_rect(enemy.*);
    
    should_damage_player := false;
    
    // TODO: make direction-independent
    // this will likely require quite a bit of work, need to consider how we want to rotate/transform collision rects or if we want to do something non-rect based
    if aabb_frect(p_rect, e_rect) {
        stomp_margin :: 2.0 / 16.0; // 2 pixels
        player_on_top := p_rect.y + p_rect.h - max(player.velocity.y, 0) < e_rect.y + stomp_margin;
        
        player_controller := get_controller(player);
        
        if player_on_top {
            player.position.y -= max((p_rect.y + p_rect.h) - e_rect.y, 0);
            player.entity_flags |= .ON_GROUND;
            player.ground_velocity = position - position_prev;
            if player.velocity.y > enemy.velocity.y then player.velocity.y = enemy.velocity.y;
            
            // player can pick up entity when standing on top of it
            if player_controller.THROW.state == .PRESSED {
                enemy.entity_flags |= .HELD;
                enemy.rotation = PI;
                
                player.held_entity_handle = enemy.handle;
                player.pickup_lerp = 0;
                player_controller.THROW.state = .DOWN; // prevent trying to pick up two entities in one frame
                
                play(*template.noises.pick_up);
            }
            
        }
        
        should_damage_player ||= !player_on_top;
    }
    
    if should_damage_player {
        try_damage_player(player);
    }
}


unload_enemy_templates :: () {
    for *t: enemy_templates {
        for *a: t.animations  array_reset(*a.frames);
    }
    array_reset(*enemy_templates);
}

load_enemy_templates :: () -> bool {
    if enemy_templates  unload_enemy_templates();
    
    ok := LSD.load_and_parse_file("data/enemy_templates.gon", #code {
        LS.set_variable(*parser.script, "default_enemy_physics", default_enemy_physics);
        LS.set_variable(*parser.script, "UPDATES_PER_FRAME", UPDATES_PER_FRAME);
        LS.set_variable(*parser.script, "UPDATES_PER_SECOND", UPDATES_PER_SECOND);
        
        LS.register_procedure(*parser.script, "palette", #procedure_of_call get_palette_index(""));
        LS.register_procedure(*parser.script, "sound", load_sfx);
        LS.register_procedure(*parser.script, "compute_friction", compute_friction);
        
        LSD.add_data_binding_to_dom(*parser, enemy_templates, "templates");
    });
    if !ok  return false;
    
    return true;
}
