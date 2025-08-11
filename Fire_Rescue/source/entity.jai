
/*
    In order to fix physics for enemies, we basically need to move a lot of stuff from the player into the base entity type
    while we are doing this, we may as well add the option to attach a player controller to any entity so that we have the option to make enemies player controllable in the future.
    
    we will need logic for 
    
    rotate entity velocity into its local, gravity-dependent space
        probably won't do this unless we actaully implement gravity stuff later
        which I will probabyl not do for this game...
    apply ground rotation velocity
    
    determine run normal for entity
    
    
    unrelated:
        player graphics should just be aligned based on bottom of player hitbox (instead of being offset by -clipsize/2, centered on player origin)
*/


Entity :: struct {
    entity_type:    Entity_Type;
    handle:         Entity_Handle;
    
    // may relocate to player later, if most of these end up being player specific
    Flags :: enum_flags {
        ON_GROUND;
        SLIDING;
        HELD;
        THROWN;
        REMOVE_ME;
        IN_BLOCK;
        IS_SPAWNER_EXEMPLAR;
        SELECTED_IN_EDITOR;
    };
    entity_flags: Flags;
    
    position:                   Vector2;
    position_prev:              Vector2;
    size:                       Vector2;
    
    gravity_angle:              float = 90;
    last_ground_angle:          float;
    
    velocity:                   Vector2;
    ground_velocity:            Vector2;
    ground_rotation_velocity:   Vector2;
    ground_conveyor_velocity:   Vector2;
    
    // debug
    last_velocity_adjust:       Vector2;
    
    rotation:                   float;
    
    collision_data:             Tilemap_Collision_Data;
    collision_points:           Enumerated_Array(Direction, Tilemap_Collision_Point);
    dbg_collision_mask:         Direction_Set;
    
    palette:                    int;
    
    in_block: struct {
        tile_serial:    u32;
        sort_order:     u32;
        multi_entity:   int;    // will spawn copies of itself instead of just releasing itself
        // timed:          float;  // e.g. a timed coin block, where you can get as many as possible before timer expires
    }
    
    // if entity was spawned by a spawner, we hold a handle to that spawner
    // this is so that we can decrement spawner's counter on death and such
    spawner_handle:             Entity_Handle;
    
    attached_to_tilemap: int = -1;
    
    ticks_since_thrown: int;
    
    // audio-related
    // walk_noise_accumulator: float;
}

Entity_Type :: enum {
    NONE;
    PLAYER;
    ENEMY;
    FIRE_BAR;
    WARP;
    ITEM;
}

// All entities will have an Entity as their first member, so it is always safe to cast any entity type to an Entity.
Entity_Union :: union {
    using #as base: Entity;
    enemy:          Enemy;
    fire_bar:       Fire_Bar;
    warp:           Warp;
    item:           Item;
}

// used in Data Packer remap_union callback 
resolve_entity_union_data := Data_Packer.Resolve_Union_By_Tag_Data.{ "entity_type", type_info(Entity_Type), type_info(Entity_Union), .[
    .{ #run Number_Union.from(Entity_Type.ENEMY),    "enemy"    },
    .{ #run Number_Union.from(Entity_Type.FIRE_BAR), "fire_bar" },
    .{ #run Number_Union.from(Entity_Type.WARP),     "warp"     },
    .{ #run Number_Union.from(Entity_Type.ITEM),     "item"     },
]};

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

get :: (handle: Entity_Handle, expected_type := Entity_Type.NONE) -> *Entity {
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


update_entity :: (using entity: *Entity) {
    if entity.entity_flags & .IN_BLOCK  return;
    
    if entity_type == {
        case .ENEMY;    update_enemy      (xx entity);
        case .FIRE_BAR; update_fire_bar   (xx entity);
        case .WARP;     update_warp       (xx entity);
        case .ITEM;     update_item       (xx entity);
    }
}

prep_entity :: (using entity: *Entity) {
    
}

// needs to be called whenever an entity is removed, both in editor or active level
deinit_entity :: (using entity: *Entity) {
    entity.* = .{};
}

render_entity :: (using entity: *Entity, render_unit: float, offset: Vector2, alpha_mod: float = 1) {
    if entity.entity_flags & .IN_BLOCK  return;
    
    if entity_type == {
        case .ENEMY;    render_enemy      (xx entity, render_unit, offset, alpha_mod);
        case .FIRE_BAR; render_fire_bar   (xx entity, render_unit, offset, alpha_mod);
        case .WARP;     render_warp       (xx entity, render_unit, offset, alpha_mod);
        case .ITEM;     render_item       (xx entity, render_unit, offset, alpha_mod);
    }
}

get_collision_rect :: (using entity: *Entity) -> Rectf {
    if entity_type == {
        case .ENEMY;    return get_collision_rect(entity.(*Enemy));
        case .FIRE_BAR; return get_collision_rect(entity.(*Fire_Bar));
    }
    
    // default behaviour for very simple entities
    return .{ position = position - size / 2, size = size };
}

player_collide_entity :: (player: *Player, entity: *Entity, entity_index: int) {
    if entity.entity_type == {
        case .ENEMY;  enemy_collide_plumber (xx entity, player, entity_index);
    }
}

// TODO: we should probably just have one proc for handling entity-to-entity collision events such as shell/fireball/thrown enemy collisions
//       collision type and other involved entity should be passed as well as target entity
//       this will be easier to extend in the future and prevent this stupid duplicated switch cases

Entity_Collision_Type :: enum {
    THROWN;
    SHELL;
    FIREBALL;
}

// meaning of return value depends on collision type
handle_entity_collision :: (entity: *Entity, other: *Entity, collision_type: Entity_Collision_Type) -> bool {
    if entity.entity_type == {
        case .ENEMY;  return handle_enemy_collision(entity.(*Enemy), other, collision_type);
        case .ITEM;   return handle_item_collision(entity.(*Item), other, collision_type);
        // case .PLAYER; return handle_player_collision(entity.(*Enemy), other, collision_type);
    }
    return false;
}

// TODO: move to collision file
frect_from_position_size_offset :: (position: Vector2, size: Vector2, offset: Vector2) -> Rectf {
    return Rectf.{
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    };
}

rect_from_position_size_offset :: (position: Vector2, size: Vector2, offset: Vector2) -> Rect {
    return Rect.{
        x = xx (position.x + offset.x),
        y = xx (position.y + offset.y),
        w = xx (size.x),
        h = xx (size.y),
    };
}

// TODO: probably just set some render_order int or enum instead of doing this nonsense
//       we will also want to be able to control rendering entities between certain tile layers and all that
should_render_before_player :: (entity: *Entity) -> bool {
    if entity.entity_type == {
      case .WARP;  warp := entity.(*Warp);
        // TODO: check that warp is in proper state, proper type
        return true;
        
      case .ITEM;
        return true;
    }
    
    return false;
}


get_collision_points :: (using entity: *Entity) -> [] Tilemap_Collision_Point {
    corner_dist :: Vec2f.{ 5.0 / 16.0, 7.0 / 16.0 };
    
    gravity_angle_radians := (entity.gravity_angle + 270) * PI / 180;
    
    collision_points[Direction.U ].point_relative_to_origin = rotate_radians(.{ 0, -entity.size.y / 2 }, gravity_angle_radians);
    collision_points[Direction.D ].point_relative_to_origin = rotate_radians(.{ 0,  entity.size.y / 2 }, gravity_angle_radians);
    collision_points[Direction.L ].point_relative_to_origin = rotate_radians(.{ -entity.size.x / 2, 0 }, gravity_angle_radians);
    collision_points[Direction.R ].point_relative_to_origin = rotate_radians(.{  entity.size.x / 2, 0 }, gravity_angle_radians);
    collision_points[Direction.UR].point_relative_to_origin = rotate_radians(.{  entity.size.x, -entity.size.y } * corner_dist, gravity_angle_radians);
    collision_points[Direction.DR].point_relative_to_origin = rotate_radians(.{  entity.size.x,  entity.size.y } * corner_dist, gravity_angle_radians);
    collision_points[Direction.UL].point_relative_to_origin = rotate_radians(.{ -entity.size.x, -entity.size.y } * corner_dist, gravity_angle_radians);
    collision_points[Direction.DL].point_relative_to_origin = rotate_radians(.{ -entity.size.x,  entity.size.y } * corner_dist, gravity_angle_radians);
    
    return collision_points.data;
}