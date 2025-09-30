
// for common things between player and entity
// trying to make this small for now, may remove or just go back to having actual entity subtypes
Entity_Base :: struct {
    palette:                    Palette_ID;
    flags:                      Flags;
    
    position:                   Vector2;
    position_prev:              Vector2;
    scale:                      Vector2;
    
    velocity:                   Vector2;
    ground_velocity:            Vector2;
    
    collision_data:             Tilemap_Collision_Data;
    
    ticks_since_thrown:         int;
    
    Flags :: enum_flags {
        // used by both
        ON_GROUND;
        
        // player
        GROUND_IS_SEMISOLID;
        
        // entity
        DEAD;
        POSITIONED_BY_SCRIPT;
        NO_COLLIDE_TILEMAP;
        NO_COLLIDE_PLAYER;
        PLAYER_STANDING_ON;
        IS_SPAWNER_EXEMPLAR;
        SELECTED_IN_EDITOR;
        REMOVE_ME;
        HELD;
        THROWN;
        IS_WARP;
        SNAP_TO_FLOOR_ON_LEVEL_INIT;
    };
}

Entity :: struct {
    using #as base:         Entity_Base;
    handle:                 Entity_Handle;
    name:                   [32] u8;
    group_id:               int;
    
    // if entity was spawned by a spawner, we hold a handle to that spawner so that we can decrement spawner's counter on death and such
    spawner_handle:         Entity_Handle;
    attached_to:            General_Handle;
    
    template_index:         int;
    animator:               Entity_Animator;
    
    movement_direction:     Direction;
    player_ignore_clock:    int;
    jump_clock:             int;
    
    tempo:                  float;
    init_position:          Vec2f;
    
    collision_points:       Enumerated_Array(Entity_Collision_Points, Tilemap_Collision_Point);
    
    warp:                   Warp;
    
    movement_visualizer:    Movement_Visualizer;
    
    // We just alias position and position_prev as offset_next and offset when doing immediate-mode positioning
    #place init_position;  root_offset:  Vec2f;
    #place position_prev;  offset:       Vec2f;
    #place position;       offset_next:  Vec2f;
}

Entity_Collision_Type :: enum {
    HURT;
    SOLID;
    SEMISOLID;
    TILE;
    CHECKPOINT;
    COLLECTABLE;
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


Entity_Handle :: #type,distinct Generic_Handle;

operator == :: (a: Entity_Handle, b: Entity_Handle) -> bool {
    return a.index == b.index && a.generation == b.generation;
}

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
    template := get_template(entity);
    
    palette = template.palette;
    position = init_position;
    if scale.x == 0 then scale = .{1, 1};
}

deinit_entity :: (using entity: *Entity) {
    generation := entity.handle.generation;
    entity.* = .{};
    entity.handle.generation = generation;
}

player_collide_entity :: (player: *Player, entity: *Entity) {
    if entity.flags & .NO_COLLIDE_PLAYER then return;
    
    template := get_template(entity);
    
    p_rect := get_collision_rect(player);
    e_rect := get_collision_rect(entity);
    
    entity_velocity := get_velocity(entity);
    
    if template.collision_type == {
      case .HURT;
        if aabb_frect(p_rect, e_rect) {
            try_damage_player(player);
        }
        
      case .CHECKPOINT;
        if aabb_frect(p_rect, e_rect) {
            set_checkpoint(.{
                local_id   = entity.warp.local_id,
                level_name = Game.active_level.id,
            });
        }
        
      case .SEMISOLID;
        if aabb_frect(p_rect, e_rect) {
            stomp_margin :: 4.0 / 16.0; // 2 pixels
            player_on_top := p_rect.y + p_rect.h - max(player.velocity.y - entity_velocity.y, 0) < e_rect.y + stomp_margin;
            
            if player_on_top {
                player.position.y -= max((p_rect.y + p_rect.h) - e_rect.y, 0);
                player.flags |= .ON_GROUND;
                
                player.ground_velocity = entity_velocity;
                if player.velocity.y > entity_velocity.y then player.velocity.y = entity_velocity.y;
                
            //     // player can pick up entity when standing on top of it
            //     if player_controller.THROW.state == .PRESSED {
            //         entity.flags |= .HELD;
                    
            //         player.held_entity_handle = entity.handle;
            //         player.pickup_lerp = 0;
            //         player_controller.THROW.state = .DOWN; // prevent trying to pick up two entities in one frame
                    
            //         play(*template.noises.pick_up);
            //     }
            }
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

get_all_entities_in_group :: (group_id: int) -> [] *Entity {
    group: [..] *Entity;
    group.allocator = temp;
    for *context.current_level.entities {
        if it.group_id == group_id  array_add(*group, it);
    }
    return group;
}

get_all_entities_in_group :: (group_name: string) -> [] *Entity {
    for *to_view(*context.current_level.entity_groups) {
        if to_string(it) == group_name {
            return get_all_entities_in_group(it_index);
        }
    }
    return .[];
}


Entity_Template :: struct {
    name:               string;
    uuid:               u64;
    palette:            Palette_ID;
    animations:         Entity_Animations;
    physics:            Entity_Physics;
    noises:             Entity_Sounds;
    
    collision_type:     Entity_Collision_Type;
    // tile_info:          Tile_Info;
    
    // for now, we presume this is always the same.
    // if need be in the future, we can probably just put the collision data in the animation
    collision_size:     Vector2;
    
    flags: Flags;
    Flags :: enum_flags {
        DONT_WALK_OFF_LEDGES;
        STAY_FACING_PLAYER;
        CHASE_PLAYER;
        MATCH_PLAYER_JUMP;
        CAN_FLOAT;
        
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
            * move left/right, turn around when hitting a wall or (optionally) when hitting a ledge
            also optionally follow the player
            also optionally move faster when player is on the same ground level 
        floaters
            * float left/right or up/down, turn around when hitting a wall
            or float towards player like a Boo,
                may require adding additional offset value to position, which can be changed independently
                    this would also help if implementing chain chomp-type enemies, so we know the base position to return to
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
            
            
            
    Immediate-Mode Entities
    
    Another very important element to the game's design will be take the idea of 'immediate-mode' and applying it to the semantics of the level design
    So we will have some mechanism in the scripts to create and manage entities in an immeidate-mode sort of way.
    For example, if we want to create a fire bar a la mario 1, we can define some function of time which generates the instantaneous state of the fire bar and the fireballs which make it up.
    Certain things (e.g. total number of fireballs) will have to be known at script 'compile-time' for the sake of resource/state management, but as far as the design interface is concerned, it's entirely immediate-mode.
    
    the fire bar case will probably be a good first example/test case of this kind of design
    from there, we could expand the idea to create platforms and other solid entities with more complex collision properties or state
    even stateful things like crumbling platforms or entire tilemap instances could be done in an immediate-mode way
    
    and this immediate-mode interface which presents level elements as semantic constructs should lend itself very well towards randomization
    imagine what could be done by combining the micro-randomizations of color tiles, interchangeable tilemap sets, and immediate-mode tilemaps in scripts
    the contents of tilemaps, the tilemaps themselves, and the manner in which they are arranged and move could all be individually tweak by the randomization engine on level load
    
    
*/

Entity_Physics :: struct {
    walk_speed:         float;
    walk_accel:         float;
    
    run_speed:          float;
    run_accel:          float;
    
    float_speed:        float;
    float_accel:        float;
    
    air_speed:          float;
    air_accel:          float;
    
    ground_friction:    float;
    stop\ _friction:    float;
    air\  _friction:    float;
    
    max_air_speed:      float;
    
    gravity:            float;
    max_fall_speed:     float;
}

adjust_for_tempo :: (physics: Entity_Physics, tempo: float) -> Entity_Physics {
    ret := physics;
    ret.walk_speed      *= tempo;
    ret.walk_accel      *= tempo;
    ret.run_speed       *= tempo;
    ret.run_accel       *= tempo;
    ret.float_speed     *= tempo;
    ret.float_accel     *= tempo;
    ret.air_speed       *= tempo;
    ret.air_accel       *= tempo;
    // TODO: figure out how to properly adjust friction values
    // ret.ground_friction *= tempo;
    // ret.stop\ _friction *= tempo;
    // ret.air\  _friction *= tempo;
    ret.max_air_speed   *= tempo;
    ret.gravity         *= tempo;
    ret.max_fall_speed  *= tempo;
    return ret;
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

find_entity_template_index_by_name :: (name: string) -> int {
    for entity_templates
        if it.name == name  return it_index;
    return 0;
}

find_entity_template_index_by_uuid :: (uuid: u64) -> int {
    for entity_templates 
        if it.uuid == uuid  return it_index;
    return 0;
}

// so we can call from scripts
// this should not be necessary, but we need to fix some typechecking things...
has_flag :: (entity: Entity, flag: Entity.Flags) -> bool { return (entity.flags & flag) == flag; }

get_size :: (entity: *Entity) -> Vec2f {
    template := get_template(entity);
    return template.collision_size * entity.scale;
}

get_velocity :: (entity: *Entity) -> Vec2f {
    if entity.flags & .POSITIONED_BY_SCRIPT {
        return entity.offset_next - entity.offset;
    }
    return entity.velocity;
}

get_position :: (entity: *Entity) -> Vec2f {
    if entity.flags & .POSITIONED_BY_SCRIPT {
        return entity.position_prev;
    }
    return entity.position;
}

snap_to_floor :: (using entity: *Entity) {
    level := context.current_level;
    while !entity.flags & .ON_GROUND {
        for *tilemap, tilemap_index: level.tilemaps {
            if tilemap.flags & .DISABLE_COLLISIONS  continue;
            do_tilemap_collision(tilemap, entity);
        }
        if position.y > level.bounds.y + level.bounds.h + 2 {
            flags |= .REMOVE_ME;
            return;
        }
        position.y += 0.1;
    }
}

update_entity_prescript :: (using entity: *Entity) {
    position_prev = position;
    flags &= ~(.NO_COLLIDE_PLAYER);
}

update_entity_postscript :: (using entity: *Entity) {
    level    := context.current_level;
    template := get_template(entity);
    physics  := adjust_for_tempo(template.physics, tempo * level.tempo);
    
    SPEED_EPSILON := units_per_second(0.1);
    
    // TODO: implement wrapping behaviour that respects level's wrapping configuration
    // check if the entity has fallen out of the level
    if position.y > level.bounds.y + level.bounds.h + 2 {
        flags |= .REMOVE_ME;
        return;
    }
    
    
    should_do_movement      := true;
    should_collide_tilemaps := true;
    should_collide_entities := true;
    
    if .NO_COLLIDE_TILEMAP & flags 
    || .NO_COLLIDE_TILEMAP & template.flags {
        should_collide_tilemaps = false;
    }
    
    if .POSITIONED_BY_SCRIPT & flags {
        should_collide_tilemaps = false;
        should_do_movement      = false;
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
        
    velocity_relative_to_ground := velocity - (ground_velocity);

    // determine desired direction of movement
    left\  _pressed := movement_direction == .L;
    right\ _pressed := movement_direction == .R;
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
    } else {
        // air friction and accel
        if abs(velocity.x) > physics.max_air_speed {
            velocity.x *= physics.air_friction;
        }
    }
    
    if should_do_movement {
        if template.flags & .CAN_FLOAT {
            top_speed = physics.float_speed;
            accel     = physics.float_accel;
            
            if movement_direction == {
              case .D; velocity.y += clamp( top_speed - velocity.y,      0, accel);
              case .U; velocity.y += clamp(-top_speed - velocity.y, -accel,     0);
              case .R; velocity.x += clamp( top_speed - velocity.x,      0, accel);
              case .L; velocity.x += clamp(-top_speed - velocity.x, -accel,     0);
            }
        } else {
            // if walk dir is not valid and entity is on the ground, 
            // then pick the direction to walk based on current velocity
            // this behaviour is used intentionally when items/enemies pop out of item blocks
            if movement_direction != .L && movement_direction != .R {
                if .ON_GROUND & flags {
                    movement_direction = ifx velocity.x > 0 then .R else .L;
                }
            }
            
            applicable_accel: float;
            if movement_direction == {
              case .R; applicable_accel = clamp( top_speed - velocity_relative_to_ground.x,      0, accel);
              case .L; applicable_accel = clamp(-top_speed - velocity_relative_to_ground.x, -accel,     0);
            }
            velocity.x += applicable_accel;
        }
        
        applied_gravity := physics.gravity;
        velocity.y = min(physics.max_fall_speed, velocity.y + applied_gravity);
        
        position += velocity;
    }
    
    
    
    
    // ===== Collision =====
    
    flags &= ~(.PLAYER_STANDING_ON);
    flags &= ~(.ON_GROUND);
    
    if should_collide_tilemaps {
        ground_found_left  := false;
        ground_found_right := false;
        
        for *tilemap, tilemap_index: level.tilemaps {
            if tilemap.flags & .DISABLE_COLLISIONS  continue;
            
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
            if !ground_found_left  then movement_direction = .R;
            if !ground_found_right then movement_direction = .L;
        }
    }
    
    if should_collide_entities {
        // TODO: collision between entities
    }
    
    {
        using movement_visualizer;
        if type == {
          case .LINE;
            line.p1         = root_offset;
            line.p2         = offset;
            line.thickness  = 1.0/8;
            line.palette    = entity.palette;
            line.color      = .{ 0.5, 0.5, 0.5, 1 };
            
          case .DOTTED_LINE;
            dotted_line.p1          = root_offset;
            dotted_line.p2          = offset;
            dotted_line.point_size  = to_Vec2f(1.0/8);
            dotted_line.palette     = entity.palette;
            dotted_line.color       = .{ 0.5, 0.5, 0.5, 1 };
            
          case .TELESCOPE;
            telescope.p1         = root_offset;
            telescope.p2         = offset;
            telescope.min_thickness  = 1.0/8;
            telescope.max_thickness  = 1.0/2;
            telescope.segments    = 3;
            telescope.palette    = entity.palette;
            telescope.color      = .{ 0.5, 0.5, 0.5, 1 };
        }
    }
    
    return;
}

render_entity :: (using entity: *Entity, render_unit: float, render_offset: Vector2, alpha_mod: float = 1) {
    if entity.template_index < 0 || entity.template_index > entity_templates.count  return;
    template := get_template(entity);
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
    else if movement_direction == .R then flip ^= .HORIZONTAL; 
    
    
    clip := current_frame.clip;
    
    clip_offset     := current_frame.offset / tile_texture_size * scale;
    render_position := (position + clip_offset + render_offset) * render_unit;
    render_size     := scale * to_Vector2(clip.size) / 16.0 * render_unit;
    
    render_draw_quad(
        texture  = *textures.ENTITIES,
        color    = .{ 1, 1, 1, alpha_mod },
        position = render_position,
        size     = render_size,
        clip     = *rect_to_frect(current_frame.clip),
        flip     = flip,
        palette  = entity.palette,
    );
    
    // collision_rect := get_collision_rect(entity);
    // collision_rect.position += offset;
    // collision_rect *= render_unit;
    // render_draw_rect(
    //     rect  = collision_rect,
    //     color = .{0,1,0,1},
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
    template := get_template(entity);
    
    update_entity_animation_state(entity);
    step_animator(*animator, template.animations.data, Game.render_delta_time);
}

update_entity_animation_state :: (using entity: *Entity) {
    template := get_template(entity);
    
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

get_collision_rect :: (using entity: *Entity) -> Rectf {
    size := get_size(entity);
    return .{ position = position - size / 2, size = size };
}


// not used in render_entity, because we need the other info in current_frame
// will probably use this for the preview in editor
get_entity_render_clip :: (using entity: Entity) -> Rect {
    if entity.template_index < 0 || entity.template_index > entity_templates.count  return .{};
    template := get_template(entity);
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

// NOTE: this assumes entity is in the context.current_level's entities array!
//       if not, then the no_handle flag needs to be passed or the game will crash
init_entity :: (entity: *Entity, template_index: int, movement_direction: Direction = .L, no_handle := false) {
    generation := entity.handle.generation + 1;
    
    entity.* = .{};
    entity.template_index       = template_index;
    entity.movement_direction   = movement_direction;
    entity.animator.state       = .WALK;
    
    if !no_handle {
        entity.handle = .{ get_element_index(*context.current_level.entities, entity), generation };
    }
    
    template := get_template(entity);
    entity.palette = template.palette;
    
    entity.scale = .{1, 1};
}

get_template :: (entity: Entity) -> *Entity_Template {
    return *entity_templates[entity.template_index];
}

handle_entity_collision :: (entity: *Entity, other: *Entity, collision_type: Entity_Collision_Type) -> bool {
    template := get_template(entity);
    
    if collision_type == {
      case .HURT;
        
    }
    
    return false;
}

kill_entity :: (using entity: *Entity) {
    template := get_template(entity);
    flags |= .DEAD | .NO_COLLIDE_TILEMAP;
    flags &= ~.HELD;
    flags |= .THROWN;
    play(template.noises.hit);
}


unload_entity_templates :: () {
    for *t: entity_templates {
        for *a: t.animations  array_reset(*a.frames);
        free(t.name);
    }
    array_reset(*entity_templates);
}

load_entity_templates :: () -> bool {
    if entity_templates  unload_entity_templates();
    
    ok := LSD.load_and_parse_file("data/entity_templates.lsd", #code {
        LS.set_variable(*parser.script, "default_entity_physics", default_entity_physics);
        
        LSD.add_data_binding_to_dom(*parser, default_entity_physics, "default_entity_physics");
        LSD.add_data_binding_to_dom(*parser, entity_templates,       "templates");
    });
    if !ok  return false;
    
    
    for *entity_templates {
        using it.physics;
        
        walk_speed   /= updates_per_second;
        run_speed    /= updates_per_second;
        air_speed    /= updates_per_second;
        float_speed  /= updates_per_second;
        
        walk_accel  = walk_speed   / (walk_accel   * updates_per_second);
        run_accel   = run_speed    / (run_accel    * updates_per_second);
        air_accel   = air_speed    / (air_accel    * updates_per_second);
        float_accel = float_speed  / (float_accel  * updates_per_second);
        
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
    
    template := get_template(entity);
    
    tilemap_velocity := get_velocity(tilemap);
    
    position_in_tilemap = get_position_in_tilemap(tilemap, entity.position);
    velocity_in_tilemap = entity.velocity - tilemap_velocity;
    
    // TODO: fix
    // if !broad_phase_collision_check(tilemap, position_in_tilemap, 4)  return;
    
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
            if entity.velocity.x < tilemap_velocity.x {
                entity.velocity.x = tilemap_velocity.x;
            }
            entity.movement_direction = .R;
        }
    }
    
    if points.R.had_collision {
        point := *points.R;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            entity.position.x -= position_in_tile.x;
            if entity.velocity.x > tilemap_velocity.x {
                entity.velocity.x = tilemap_velocity.x;
            }
            entity.movement_direction = .L;
        }
    }
    
    bonk_prevention_fudge_factor := units_per_second(0.5);
    
    if points.U.had_collision {
        point := *points.U;
        position_in_tile := point.point_in_tilemap - floor(point.point_in_tilemap);
        if !(point.tile_info.collision.flags & .SEMISOLID) {
            entity.position.y += 1 - position_in_tile.y;
            if entity.velocity.y < tilemap_velocity.y {
                entity.velocity.y = tilemap_velocity.y;
            }
            if template.flags & .CAN_FLOAT then entity.movement_direction = .D;
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
                    if entity.velocity.y < tilemap_velocity.y {
                        entity.velocity.y = tilemap_velocity.y;
                    }
                    if template.flags & .CAN_FLOAT then entity.movement_direction = .D;
                  case .L;
                    entity.position.x += 1 - position_in_tile.x;
                    if entity.velocity.x < tilemap_velocity.x {
                        entity.velocity.x = tilemap_velocity.x;
                    }
                    entity.movement_direction = .R;
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
                    if entity.velocity.y < tilemap_velocity.y {
                        entity.velocity.y = tilemap_velocity.y;
                    }
                    if template.flags & .CAN_FLOAT then entity.movement_direction = .D;
                  case .R; 
                    entity.position.x -= position_in_tile.x;
                    if entity.velocity.x > tilemap_velocity.x {
                        entity.velocity.x = tilemap_velocity.x;
                    }
                    entity.movement_direction = .L;
                }
            }
        }
    }
    
    push_point_up :: (point: *Tilemap_Collision_Point, position_in_tile: Vec2f) #expand {
        entity.position.y -= position_in_tile.y;
        if entity.velocity.y > tilemap_velocity.y {
            entity.velocity.y = tilemap_velocity.y;
        }
        if template.flags & .CAN_FLOAT then entity.movement_direction = .U;
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
                if entity.velocity.x < tilemap_velocity.x {
                    entity.velocity.x = tilemap_velocity.x;
                }
                entity.movement_direction = .R;
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
                if entity.velocity.x > tilemap_velocity.x {
                    entity.velocity.x = tilemap_velocity.x;
                }
                entity.movement_direction = .L;
            }
        }
    }
    
    if apply_ground_velocity {
        entity.ground_velocity = tilemap_velocity; // + conveyor_velocity;
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
    
    size := get_size(entity);
    
    collision_points.U  = .{ point_relative_to_origin = .{ 0, -size.y / 2 } }; 
    collision_points.D  = .{ point_relative_to_origin = .{ 0,  size.y / 2 } }; 
    collision_points.L  = .{ point_relative_to_origin = .{ -size.x / 2, 0 } }; 
    collision_points.R  = .{ point_relative_to_origin = .{  size.x / 2, 0 } }; 
    collision_points.UR = .{ point_relative_to_origin = .{  size.x, -size.y } * corner_dist }; 
    collision_points.DR = .{ point_relative_to_origin = .{  size.x,  size.y } * corner_dist }; 
    collision_points.UL = .{ point_relative_to_origin = .{ -size.x, -size.y } * corner_dist }; 
    collision_points.DL = .{ point_relative_to_origin = .{ -size.x,  size.y } * corner_dist }; 
    
    collision_points.GROUND_PROBE_LOW_LEFT   = .{ point_relative_to_origin = .{ -size.x/2 - 0.1, size.y/2 + 0.25 } };
    collision_points.GROUND_PROBE_LOW_RIGHT  = .{ point_relative_to_origin = .{  size.x/2 + 0.1, size.y/2 + 0.25 } };
    collision_points.GROUND_PROBE_HIGH_LEFT  = .{ point_relative_to_origin = .{ -size.x/2 - 0.1, 0 } };
    collision_points.GROUND_PROBE_HIGH_RIGHT = .{ point_relative_to_origin = .{  size.x/2 + 0.1, 0 } };
}

/*
    Very simplified example for our first immediate-mode entity.
    This only uses the entity template for the purposes of getting a collision rect and animation for rendering.
        It does not consider the ususal collision type or movement properties associated with the template.
*/
immediate_fireball :: (template_index: int, position: Vec2f, scale := Vec2f.{1,1}) {
    if template_index < 0 || template_index > entity_templates.count  return;
    template := *entity_templates[template_index];
    level := context.current_level;
    
    size := template.collision_size;
    
    {
        p_rect := get_collision_rect(*Game.player);
        e_rect := Rectf.{ position = position - size / 2, size = size };
        
        if aabb_frect(p_rect, e_rect) {
            try_damage_player(*Game.player);
        }
    }
    
    while 1 { defer break;
        render_unit := context.layout_context.tile_unit;
        render_offset: Vector2 = -context.current_level.camera;
        
        // TODO: make animation state a parameter
        animation_state := Entity_Animation_States.WALK;
        animation := *template.animations[animation_state];
        if !animation.frames  break;
        
        current_frame := get_animation_frame_at_time(animation, level.time_since_start);
        flip          := current_frame.flip;
        clip          := current_frame.clip;
        
        // if .STAY_FACING_PLAYER & template.flags {
        //     if Game.player.position.x > position.x 
        //         then flip |=  .HORIZONTAL;
        //         else flip &= ~.HORIZONTAL;
        // }
        // else if entity.movement_direction == .R then flip ^= .HORIZONTAL; 
        
        clip_offset     := current_frame.offset / tile_texture_size * scale;
        render_position := (position + clip_offset + render_offset) * render_unit;
        render_size     := scale * to_Vector2(clip.size) / 16.0 * render_unit;
        
        cmd := Render_Command.{
            type = .QUAD,
            quad_params = .{
                texture  = *textures.ENTITIES,
                // color    = .{ 1, 1, 1, alpha_mod },
                position = render_position,
                size     = render_size,
                clip     = *rect_to_frect(current_frame.clip),
                flip     = flip,
                palette  = template.palette,
            }
        };
        
        array_add(*immediate_entity_render_commands, cmd);
    }
}

immediate_entity_render_commands: [..] Render_Command;




Movement_Visualizer_Type :: enum {
    NONE :: 0;
    LINE :: 1;
    DOTTED_LINE;
    TELESCOPE;
}

Movement_Visualizer :: struct {
    type: Movement_Visualizer_Type;
    union {
        line: struct {
            p1, p2:     Vec2f;
            thickness:  float;
            palette:    Palette_ID;
            color:      Color4;
        };
        dotted_line: struct {
            p1, p2:     Vec2f;
            point_size: Vec2f;
            palette:    Palette_ID;
            color:      Color4;
        };
        telescope: struct {
            p1, p2:         Vec2f;
            min_thickness:  float;
            max_thickness:  float;
            segments:       int;
            palette:        Palette_ID;
            color:          Color4;
        };
    }
}

render_movement_visualizer :: (using visualizer: Movement_Visualizer, render_unit: float, offset: Vec2f) {
    if type == {
      case .LINE;
        p1 := (line.p1 + offset) * render_unit;
        p2 := (line.p2 + offset) * render_unit;
        
        time := seconds_since_init().(float);
        line_color := get_current_color(line.palette, time) * line.color;
        
        render_draw_line(p1, p2, color = line_color, thickness = line.thickness);
        
      case .DOTTED_LINE;
        distance_between_endpoints := distance(dotted_line.p1, dotted_line.p2);
        distance_between_points    := 0.5;
        
        // TODO: we should calculate the number of points only once and then put that as a member in dotted_line
        //       that way we can render dotted line chains that appear to stretch and we won't get weird glitching when rounding is weird
        number_of_points := snap_to_nearest_unit(distance_between_endpoints / distance_between_points, 1).(int);
        move_per_point   := (dotted_line.p2 - dotted_line.p1) / number_of_points.(float) * render_unit;
        
        point      := (offset + dotted_line.p1 - dotted_line.point_size / 2) * render_unit;
        point_size := dotted_line.point_size * render_unit;
        
        for 0..number_of_points-1 {
            render_draw_quad(
                position = point,
                size     = point_size,
                palette  = dotted_line.palette,
                color    = dotted_line.color,
            );
            point += move_per_point;
        }
        
      case .TELESCOPE;
        time := seconds_since_init().(float);
        line_color := get_current_color(telescope.palette, time) * telescope.color;
        
        for 0..telescope.segments-1 {
            it_lerp := it.(float)/telescope.segments.(float);
            
            thickness := lerp(telescope.min_thickness, telescope.max_thickness, it_lerp) * render_unit;;
            
            p1 := (telescope.p1 + offset) * render_unit;
            p2 := (lerp(telescope.p1, telescope.p2, 1.0-it_lerp) + offset) * render_unit;
            
            render_draw_line(p1, p2, color = line_color * .{0.5+0.5*it_lerp,0.5+0.5*it_lerp,0.5+0.5*it_lerp,1}, thickness = thickness);
        }
    }
}



