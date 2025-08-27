
/*
    Trying to figure out our Entity ontology here...
    
    Going to just try putting almost everything into one struct for now.
    Except of course, the player.
*/

// for common things between player and entity
// trying to make this small for now, may remove or just go back to having actual entity subtypes
Entity_Base :: struct {
    palette:                    int;
    flags:                      Flags;
    
    position:                   Vector2;
    position_prev:              Vector2;
    size:                       Vector2;
    
    velocity:                   Vector2;
    ground_velocity:            Vector2;
    
    collision_data:             Tilemap_Collision_Data;
    
    attached_to_tilemap:    int = -1;
    
    ticks_since_thrown:     int;
        
    Flags :: enum_flags {
        // used by both
        ON_GROUND;
        
        // player
        GROUND_IS_SEMISOLID;
        
        // entity
        AWAKE;
        DEAD;
        NO_COLLIDE_TILEMAP;
        NO_COLLIDE_PLAYER;
        PLAYER_STANDING_ON;
        IS_SPAWNER_EXEMPLAR;
        SELECTED_IN_EDITOR;
        REMOVE_ME;
        HELD;
        THROWN;
        IS_WARP;
    };
}

Entity :: struct {
    using #as base:         Entity_Base;
    handle:                 Entity_Handle;
    
    // if entity was spawned by a spawner, we hold a handle to that spawner so that we can decrement spawner's counter on death and such
    spawner_handle:         Entity_Handle;
    
    template_index:         int;
    animator:               Entity_Animator;
    
    walk_direction:         Direction;
    player_ignore_clock:    int;
    jump_clock:             int;
    
    init_position:          Vec2f;
    
    collision_points:       Enumerated_Array(Entity_Collision_Points, Tilemap_Collision_Point);
    
    warp:                   Warp;
    
    collision_type:         Entity_Collision_Type;
}

Entity_Collision_Type :: enum {
    HURT;
    SOLID;
    SEMISOLID;
    BOUNCE;
}

Entity_Collision_Points :: enum {
    U  :: Direction.U;
    R  :: Direction.R;
    D  :: Direction.D;
    L  :: Direction.L;
    UR :: Direction.UR;
    DR :: Direction.DR;
    DL :: Direction.DL;
    UL :: Direction.UL;
    
    GROUND_PROBE_LOW_LEFT;
    GROUND_PROBE_LOW_RIGHT;
    GROUND_PROBE_HIGH_LEFT;
    GROUND_PROBE_HIGH_RIGHT;
}

// all entities use a common set of sounds, which are defined in entity templates
Entity_Sounds :: struct {
    jump:       Noise;
    pick_up:    Noise;
    throw:      Noise;
    hit:        Noise;
    bump:       Noise;
    bounce:     Noise;
    land:       Noise;
    
    damage:     Noise;
    die:        Noise;
}

Entity_Handle :: struct {
    index, generation: int;
};

get :: (handle: Entity_Handle) -> *Entity {
    if handle.index < 0 || handle.generation < 0  return null;
    
    entities := *context.current_level.entities;
    entity := *entities.slots[handle.index];
    if entity.handle.generation == handle.generation  return entity;
    
    return null;
}

init_all_entity_handles :: (level: *Level_Layout) {
    for *level.entities {
        it.handle.index = it_index;
        // it.handle.generation = 0;
    }
}

// in theory, this would run whenever the entity wakes up or something like that
// maybe we will use this when we figure out what we're supposed to do about re-initializing entities on player entering/exiting particular camaera zones
prep_entity :: (using entity: *Entity) {
    
}

deinit_entity :: (using entity: *Entity) {
    entity.* = .{};
}

player_collide_entity :: (player: *Player, entity: *Entity, entity_index: int) {
    if entity.flags & .NO_COLLIDE_PLAYER then return;
    
    template := *entity_templates[entity.template_index];
    
    p_rect := get_collision_rect(player);
    e_rect := get_collision_rect(entity);
    
    if aabb_frect(p_rect, e_rect) {
        stomp_margin :: 2.0 / 16.0; // 2 pixels
        player_on_top := p_rect.y + p_rect.h - max(player.velocity.y, 0) < e_rect.y + stomp_margin;
        
        player_controller := get_controller(player);
        
        if player_on_top {
            player.position.y -= max((p_rect.y + p_rect.h) - e_rect.y, 0);
            player.flags |= .ON_GROUND;
            player.ground_velocity = entity.position - entity.position_prev;
            if player.velocity.y > entity.velocity.y then player.velocity.y = entity.velocity.y;
            
            // player can pick up entity when standing on top of it
            if player_controller.THROW.state == .PRESSED {
                entity.flags |= .HELD;
                
                player.held_entity_handle = entity.handle;
                player.pickup_lerp = 0;
                player_controller.THROW.state = .DOWN; // prevent trying to pick up two entities in one frame
                
                play(*template.noises.pick_up);
            }
            
        }
        
        if entity.collision_type == .HURT {
            try_damage_player(player);
        }
    }
}

// TODO: probably just set some render_order int or enum instead of doing this nonsense
//       we will also want to be able to control rendering entities between certain tile layers and all that
should_render_before_player :: (entity: *Entity) -> bool {
    // if entity.entity_type == {
    //   case .WARP;  warp := entity.(*Warp);
    //     // TODO: check that warp is in proper state, proper type
    //     return true;
    // }
    
    return false;
}














Entity_Template :: struct {
    name:           string;
    uuid:           u64;
    palette:        int;
    animations:     Entity_Animations;
    physics:        Entity_Physics;
    noises:         Entity_Sounds;
    
    // defines a broad general movement type, mutually exclusive
    // particulars of movement style may be modified by flags
    // movement_style: Movement_Style;
    // Movement_Style :: enum { 
    //     NONE   :: 0;
        
    //     // currently same as .NONE, but here to signal intent
    //     // entity positions can be set 
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
    Entity Movement Notes
    
    I am thinking that perhaps all the movmeent styles I wantt o implement can actaulyl be implemented purely by changing the entity physics values, 
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

Entity_Physics :: struct {
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

default_entity_physics: Entity_Physics;

Entity_Animation_States :: enum {
    WALK;
    JUMP;
    FALL;
    THROW;
    DEAD;
}

Entity_Animations :: Enumerated_Array(Entity_Animation_States, Simple_Animation(0));
Entity_Animator   :: Simple_Animator(Entity_Animation_States);

entity_templates: [..] Entity_Template;

find_entity_template_by_name :: (name: string) -> *Entity_Template {
    for *entity_templates
        if it.name == name  return it;
    return null;
}

find_entity_template_by_uuid :: (uuid: u64) -> *Entity_Template {
    for *entity_templates 
        if it.uuid == uuid  return it;
    return null;
}


update_entity :: (using entity: *Entity) {
    level    := context.current_level;
    template := *entity_templates[entity.template_index];
    physics  := *template.physics;
    
    SPEED_EPSILON := units_per_second(0.1);
    
    if position_prev == .{}  init_position = position; // this is very dumb, but maybe works in practice?
    
    position_prev = position;
    
    // wake up enemies when they come on screen
    // once they're awake they'll always update
    if is_point_within_frect(position, get_camera_visible_rect(.{ 4, 4 })) {
        flags |= .AWAKE;
    }
    if !(flags & .AWAKE)  return;
    
    // TODO: maybe implement some entity wrapping behavior
    // check if the entity has fallen out of the level
    if position.y > level.bounds.y + level.bounds.h + 2 {
        flags |= .REMOVE_ME;
        return;
    }
    
    velocity_relative_to_ground := velocity - (ground_velocity);
    
    flags &= ~.NO_COLLIDE_PLAYER; // this gets reset every frame
    
    should_do_movement      := true;
    should_collide_tilemaps := true;
    should_collide_entities := true;
    
    if .NO_COLLIDE_TILEMAP & flags 
    || .NO_COLLIDE_TILEMAP & template.flags {
        should_collide_tilemaps = false;
    }
    
    if .HELD & flags {
        flags |= .NO_COLLIDE_PLAYER;
        should_collide_tilemaps = false;
        should_collide_entities = false;
        should_do_movement      = false;
    }
    
    // prevent entity from interacting with player immediately after being thrown
    if ticks_since_thrown < (0.25 * updates_per_second).(int) then flags |= .NO_COLLIDE_PLAYER;
    ticks_since_thrown += 1;
    
    if .DEAD & flags {
        flags |= .NO_COLLIDE_PLAYER;
        should_do_movement      = false;
        should_collide_entities = false;
        if .STOPPED & animator.flags {
            flags |= .REMOVE_ME;
            return;
        }
    }
    
    player_ignore_clock = max(player_ignore_clock - 1, 0);
    
    
    
    // ===== Physics and Movement =====
    
    // determine desired direction of movement
    left\  _pressed := walk_direction == .L;
    right\ _pressed := walk_direction == .R;
    neither_pressed := !(left_pressed || right_pressed);
    
    top_speed := physics.walk_speed;
    accel     := physics.walk_accel;

    if flags & .ON_GROUND {
        ground_friction := physics.ground_friction;
        stop_friction   := physics.stop_friction;
        
        applied_friction := 1.0;
        
        // whether player can stick to moving ground well should also depend on absolute speed
        // TODO: move these to player physics file
        ground_stick_thresh_lower := units_per_second(1);
        ground_stick_thresh_upper := units_per_second(2);
        
        if neither_pressed || (right_pressed && velocity_relative_to_ground.x < 0) || (left_pressed && velocity_relative_to_ground.x > 0) {
            relative_ground_speed_difference := abs(velocity_relative_to_ground.x);
            if relative_ground_speed_difference < ground_stick_thresh_lower {
                applied_friction = 0;
            } else {
                actual_stop_friction := ground_friction;
                if relative_ground_speed_difference < ground_stick_thresh_upper {
                    lerp_t := clamp(delerp(0, ground_stick_thresh_upper, relative_ground_speed_difference), 0, 1);
                    actual_stop_friction = lerp(stop_friction, ground_friction, lerp_t).(float);
                }
                applied_friction = actual_stop_friction;
            }
        } else if abs(velocity_relative_to_ground.x) > top_speed {
            applied_friction = ground_friction;
        }
        
        velocity.x = lerp(ground_velocity.x, velocity.x, applied_friction);
    }
    else {
        // air friction and accel
        if abs(velocity.x) > physics.max_air_speed {
            velocity.x *= physics.air_friction;
        }
    }
    
    if should_do_movement {
        // if walk dir is not valid and entity is on the ground, 
        // then pick the direction to walk based on current velocity
        // this behaviour is used intentionally when items/enemies pop out of item blocks
        if walk_direction != .L && walk_direction != .R {
            if .ON_GROUND & flags {
                walk_direction = ifx velocity.x > 0 then .R else .L;
            }
        }
        
        if flags & .ON_GROUND {
            applicable_accel: float;
            if walk_direction == {
              case .R; 
                applicable_accel = clamp(top_speed - velocity_relative_to_ground.x, 0, accel);
              case .L; 
                applicable_accel = clamp(-top_speed - velocity_relative_to_ground.x, -accel, 0);
            }
            velocity.x += applicable_accel;
        }
    }
    
    applied_gravity := physics.gravity;
    velocity.y = min(physics.max_fall_speed, velocity.y + applied_gravity);
    
    position += velocity;
    
    
    
    // ===== Collision =====
    
    flags &= ~(.PLAYER_STANDING_ON);
    flags &= ~(.ON_GROUND);
    
    ground_found_left  := false;
    ground_found_right := false;
    
    if should_collide_tilemaps {
        for *tilemap, tilemap_index: level.tilemaps {
            do_tilemap_collision(tilemap, entity);
            
            if collision_points.GROUND_PROBE_LOW_LEFT.had_collision
            && collision_points.GROUND_PROBE_LOW_LEFT.tile_info.collision.type == .BLOCK 
            && (collision_points.GROUND_PROBE_LOW_LEFT.tile_info.collision.flags & .SOLID) {
                ground_found_left = true;
            }
            if collision_points.GROUND_PROBE_LOW_RIGHT.had_collision
            && collision_points.GROUND_PROBE_LOW_RIGHT.tile_info.collision.type == .BLOCK 
            && (collision_points.GROUND_PROBE_LOW_RIGHT.tile_info.collision.flags & .SOLID) {
                ground_found_right = true;
            }
            
            // TODO: for both high and low probe points, we should ensure that the tile we indexed is at a height which the entity can jump/step up to.
        }
        
        if (template.flags & .DONT_WALK_OFF_LEDGES) && (flags & .ON_GROUND) {
            if !ground_found_left  then walk_direction = .R;
            if !ground_found_right then walk_direction = .L;
        }
    }
    
    if should_collide_entities {
        // TODO: collision between entities
    }
    
    return;
}

render_entity :: (using entity: *Entity, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    if entity.template_index < 0 || entity.template_index > entity_templates.count  return;
    template := *entity_templates[entity.template_index];
    level := context.current_level;
    
    update_entity_animator(entity);
    
    current_animation := *template.animations[animator.state];
    if !current_animation.frames  return;
    
    current_frame := *current_animation.frames[animator.current];
    
    
    flip := current_frame.flip;
    
    if .STAY_FACING_PLAYER & template.flags {
        if Game.player.position.x > position.x 
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
        palette  = entity.palette,
    );
    
    // render_draw_rect(
    //     rect = .{ 
    //         position = (position + offset + template.collision_offset) * render_unit, 
    //         size = template.collision_size * render_unit 
    //     },
    //     color = .{1,0,0,1},
    // );
    
    // render_position = (position + offset) * render_unit;
    // render_draw_line(render_position, render_position + (last_velocity_adjust * render_unit * 1000), color = .{1,1,0,1});
    // draw_collision_points(collision_data, render_position, render_unit, dbg_collision_mask);
    // if (flags & .ON_GROUND) && (.DONT_WALK_OFF_LEDGES & template.flags) {
    //     render_draw_line(render_position + (left\_ground_probe_offset - .{ 0, 2 }) * render_unit, render_position + (left\_ground_probe_offset) * render_unit, color = ifx ground_found_left  then Color4.{0,1,0,1} else .{1,0,0,1});
    //     render_draw_line(render_position + (right_ground_probe_offset - .{ 0, 2 }) * render_unit, render_position + (right_ground_probe_offset) * render_unit, color = ifx ground_found_right then Color4.{0,1,0,1} else .{1,0,0,1});
    // }
}

update_entity_animator :: (using entity: *Entity) {
    if template_index < 0 || template_index > entity_templates.count  return;
    template := *entity_templates[template_index];
    
    update_entity_animation_state(entity);
    step_animator(*animator, template.animations.data, Game.render_delta_time);
}

update_entity_animation_state :: (using entity: *Entity) {
    template := *entity_templates[entity.template_index];
    
    if .DEAD & flags {
        set_animation(*animator, .DEAD);
    }
    else {
        // if throw.clock == 10 {
        //     set_animation(*animator, .THROW);
        // }
        if animator.state != .THROW || (animator.flags & .STOPPED) {
            if !(.ON_GROUND & flags) {
                maybe_set_animation(*animator, ifx velocity.x < 0 then .JUMP else .FALL, template.animations.data);
            } 
            else {
                set_animation(*animator, .WALK);
            }
        } 
    }
}

get_collision_rect :: (using entity: *Entity_Base) -> Rectf {
    return .{ position = position - size / 2, size = size };
}

get_collision_rect :: (using entity: *Entity) -> Rectf {
    if entity.template_index < 0 || entity.template_index > entity_templates.count  return .{};
    template := *entity_templates[entity.template_index];
    return .{
        x = (position.x + template.collision_offset.x),
        y = (position.y + template.collision_offset.y),
        w = (size.x),
        h = (size.y),
    };
}

// not used in render_entity, because we need the other info in current_frame
// will probably use this for the preview in editor
get_entity_render_clip :: (using entity: Entity) -> Rect {
    if entity.template_index < 0 || entity.template_index > entity_templates.count  return .{};
    template := *entity_templates[entity.template_index];
    current_animation := *template.animations[animator.state];
    current_frame     := *current_animation.frames[animator.current];
    return current_frame.clip;
}

get_entity_template_icon_clip :: (using template: Entity_Template, crop_x: int, crop_y: int) -> Rect {
    walk_animation := template.animations[Entity_Animation_States.WALK];
    if walk_animation.frames.count == 0  return .{};
    clip := walk_animation.frames[0].clip;
    clip.w = min(crop_x, clip.w).(s32);
    clip.h = min(crop_y, clip.h).(s32);
    return clip;
}

init_entity :: (entity: *Entity, template_index: int, walk_direction: Direction = .L) {
    entity.* = .{};
    entity.template_index = template_index;
    entity.walk_direction = walk_direction;
    entity.animator.state = .WALK;
    
    template := *entity_templates[template_index];
    entity.palette = template.palette;
    
    entity.size = template.collision_size;
}

handle_entity_collision :: (entity: *Entity, other: *Entity, collision_type: Entity_Collision_Type) -> bool {
    template := *entity_templates[entity.template_index];
    
    if collision_type == {
      case .HURT;
        
    }
    
    return false;
}

kill_entity :: (using entity: *Entity) {
    template := *entity_templates[template_index];
    flags |= .DEAD | .NO_COLLIDE_TILEMAP;
    flags &= ~.HELD;
    flags |= .THROWN;
    play(template.noises.hit);
}


unload_entity_templates :: () {
    for *t: entity_templates {
        for *a: t.animations  array_reset(*a.frames);
    }
    array_reset(*entity_templates);
}

load_entity_templates :: () -> bool {
    if entity_templates  unload_entity_templates();
    
    ok := LSD.load_and_parse_file("data/entity_templates.lsd", #code {
        LS.set_variable(*parser.script, "default_entity_physics", default_entity_physics);
        
        LS.register_procedure(*parser.script, "palette", get_color_animation_index);
        LS.register_procedure(*parser.script, "sound", load_sfx);
        
        LSD.add_data_binding_to_dom(*parser, entity_templates, "templates");
    });
    if !ok  return false;
    
    
    for *entity_templates {
        using it.physics;
        
        walk_speed /= updates_per_second;
        run_speed  /= updates_per_second;
        air_speed  /= updates_per_second;
        
        walk_accel = walk_speed / (walk_accel * updates_per_second);
        run_accel  = run_speed  / (run_accel  * updates_per_second);
        air_accel  = air_speed  / (air_accel  * updates_per_second);
        
        ground_friction = compute_friction(ground_friction);
        stop\ _friction = compute_friction(stop\ _friction);
        air\  _friction = compute_friction(air\  _friction);
        
        max_air_speed /= updates_per_second;
        
        gravity /= (updates_per_second * updates_per_second);
        max_fall_speed /= updates_per_second;
    }
    
    
    return true;
}


do_tilemap_collision :: (tilemap: *Tilemap, entity: *Entity) {
    using entity.collision_data;
    entity.collision_data = .{};
    
    template := *entity_templates[entity.template_index];
    
    position_in_tilemap = get_position_in_tilemap(tilemap, entity.position);
    velocity_in_tilemap = entity.velocity - tilemap.velocity;
    
    if !broad_phase_collision_check(tilemap, position_in_tilemap, 4)  return;
    
    reset_collision_points(entity);
    points := *entity.collision_points;
    
    for *points {
        it.point_in_tilemap = position_in_tilemap + it.point_relative_to_origin;
        it.tile_index       = to_Vec2i_floor(it.point_in_tilemap);
        it.tile_ptr         = get_tile(tilemap, it.tile_index);
        if !it.tile_ptr  continue;
        
        it.tile_info = get_tile_info(it.tile_ptr);
        
        if it.tile_info.collision.type == .BLOCK && (it.tile_info.collision.flags & .SOLID) {
            it.had_collision = true;
            had_collision = true;
        }
    }
    
    if !had_collision  return;
    
    apply_ground_velocity := false;
    
    // TODO
    collide_tile :: (tile: *Tile, entity: *Entity) {
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
            entity.position.x += 1 - position_in_tile.x;
            if entity.velocity.x < tilemap.velocity.x {
                entity.velocity.x = tilemap.velocity.x;
            }
            entity.walk_direction = .R;
        }
    }
    
    if points.R.had_collision {
        point := *points.R;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            entity.position.x -= position_in_tile.x;
            if entity.velocity.x > tilemap.velocity.x {
                entity.velocity.x = tilemap.velocity.x;
            }
            entity.walk_direction = .L;
        }
    }
    
    bonk_prevention_fudge_factor := units_per_second(0.5);
    
    if points.U.had_collision {
        point := *points.U;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            entity.position.y += 1 - position_in_tile.y;
            if entity.velocity.y < tilemap.velocity.y {
                entity.velocity.y = tilemap.velocity.y;
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
                    entity.position.y += 1 - position_in_tile.y;
                    if entity.velocity.y < tilemap.velocity.y {
                        entity.velocity.y = tilemap.velocity.y;
                    }
                  case .L;
                    entity.position.x += 1 - position_in_tile.x;
                    if entity.velocity.x < tilemap.velocity.x {
                        entity.velocity.x = tilemap.velocity.x;
                    }
                    entity.walk_direction = .R;
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
                    entity.position.y += 1 - position_in_tile.y;
                    if entity.velocity.y < tilemap.velocity.y {
                        entity.velocity.y = tilemap.velocity.y;
                    }
                  case .R; 
                    entity.position.x -= position_in_tile.x;
                    if entity.velocity.x > tilemap.velocity.x {
                        entity.velocity.x = tilemap.velocity.x;
                    }
                    entity.walk_direction = .L;
                }
            }
        }
    }
    
    push_point_up :: (point: *Tilemap_Collision_Point, position_in_tile: Vec2f) #expand {
        entity.position.y -= position_in_tile.y;
        if entity.velocity.y > tilemap.velocity.y {
            entity.velocity.y = tilemap.velocity.y;
        }
        collide_tile(point.tile_ptr, entity);
        entity.collision_data.on_ground = true;
        apply_ground_velocity = true;
    }
    
    if points.D.had_collision {
        point := *points.D;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        
        if !(point.tile_info.collision.flags & .SEMISOLID) || (max(velocity_in_tilemap.y, 0.2) > position_in_tile.y) {
            push_point_up(point, position_in_tile);
        }
    } else {
        if points.DL.had_collision {
            point := *points.DL;
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            if point.tile_info.collision.flags & .SEMISOLID {
                if max(velocity_in_tilemap.y, 0.2) > position_in_tile.y {
                    point.direction_out = .D;
                } else {
                    point.direction_out = .U; // @Hack: not a valid option, so will do nothing below
                }
            }
            else point.direction_out = ifx 1-position_in_tile.x < position_in_tile.y then .L else .D;
            
            if point.direction_out == {
              case .D;
                push_point_up(point, position_in_tile);
              case .L;
                entity.position.x += 1 - position_in_tile.x;
                if entity.velocity.x < tilemap.velocity.x {
                    entity.velocity.x = tilemap.velocity.x;
                }
                entity.walk_direction = .R;
            }
        }
        if points.DR.had_collision {
            point := *points.DR;
            position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
            
            if point.tile_info.collision.flags & .SEMISOLID {
                if max(velocity_in_tilemap.y, 0.2) > position_in_tile.y {
                    point.direction_out = .D;
                } else {
                    point.direction_out = .U; // @Hack: not a valid option, so will do nothing below
                }
            }
            else point.direction_out = ifx position_in_tile.x < position_in_tile.y then .R else .D;
            
            if point.direction_out == {
              case .D;
                push_point_up(point, position_in_tile);
              case .R; 
                entity.position.x -= position_in_tile.x;
                if entity.velocity.x > tilemap.velocity.x {
                    entity.velocity.x = tilemap.velocity.x;
                }
                entity.walk_direction = .L;
            }
        }
    }
    
    if apply_ground_velocity {
        entity.ground_velocity = tilemap.velocity; // + conveyor_velocity;
    }
    
    if on_ground {
        entity.flags |= .ON_GROUND;
    }
    
    // TODO: maybe reimplement?
    // if length(collision_data.velocity_adjust) > units_per_second(5) { 
    //     play(ifx flags & .THROWN
    //         then *template.noises.bounce 
    //         else *template.noises.land);
    // }
    
    // get hit by bumping tile below
    // for dir: Direction.[ .D, .DL, .DR ] {
    //     point := collision_points[dir];
    //     if point.had_collision && tile_is_bumping(point.tile_ptr) {
    //         vec_out := unit_vector_given_angle(collision_data.surface_angles[point.direction_out] * PI / 180);
    //         vel_adj := vec_out * units_per_second(10);
    //         entity.velocity += vel_adj;
    //         flags |= .THROWN;
    //         do_log_vel = true;
    //         break;
    //     }
    // }
}


reset_collision_points :: (using entity: *Entity) {
    corner_dist :: Vec2f.{ 5.0 / 16.0, 7.0 / 16.0 };
    
    collision_points.U  = .{ point_relative_to_origin = .{ 0, -size.y / 2 } }; 
    collision_points.D  = .{ point_relative_to_origin = .{ 0,  size.y / 2 } }; 
    collision_points.L  = .{ point_relative_to_origin = .{ -size.x / 2, 0 } }; 
    collision_points.R  = .{ point_relative_to_origin = .{  size.x / 2, 0 } }; 
    collision_points.UR = .{ point_relative_to_origin = .{  size.x, -size.y } * corner_dist }; 
    collision_points.DR = .{ point_relative_to_origin = .{  size.x,  size.y } * corner_dist }; 
    collision_points.UL = .{ point_relative_to_origin = .{ -size.x, -size.y } * corner_dist }; 
    collision_points.DL = .{ point_relative_to_origin = .{ -size.x,  size.y } * corner_dist }; 
    
    collision_points.GROUND_PROBE_LOW_LEFT   = .{ point_relative_to_origin = .{ -size.x - 0.1, size.y + 0.25 } };
    collision_points.GROUND_PROBE_LOW_RIGHT  = .{ point_relative_to_origin = .{  size.x + 0.1, size.y + 0.25 } };
    collision_points.GROUND_PROBE_HIGH_LEFT  = .{ point_relative_to_origin = .{ -size.x - 0.1, 0 } };
    collision_points.GROUND_PROBE_HIGH_RIGHT = .{ point_relative_to_origin = .{  size.x + 0.1, 0 } };
}