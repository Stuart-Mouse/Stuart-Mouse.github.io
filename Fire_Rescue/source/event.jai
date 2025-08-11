
Event_Type :: enum {
    BLOCK_HIT;
    BLOCK_DESTROYED;
}

Event :: struct {
    timestamp: u64; // updates since level init
    event_type: Event_Type;
    
    // using a union for now so that we cna just have a dynamic array for events
    // maybe later we will refactor so that events are stored in some arena and cna be of various sizes, then use pointer casting for subtype
    using data: union {
        tile_event: struct {
            tilemap_index:  int;
            tile_index:     int;
            bump_direction: Direction;
        }
    };
}

Event_Queue :: struct {
    events: [..] Event;
    first_unprocessed_event: int;
}

process_new_events :: (using queue: *Event_Queue) {
    next_index := first_unprocessed_event;
    while next_index < queue.events.count {
        process_event(queue.events[next_index]);
        next_index += 1;
    }
    first_unprocessed_event = next_index;
}

process_event :: (event: Event) {
    if #complete event.event_type == {
      case .BLOCK_HIT;        process_block_hit_event(event);
      case .BLOCK_DESTROYED;  process_block_destroyed_event(event);
    }
}

/*
    for block hit event we not only want to notify entities of block being hit, we also want to 
    notify the block back so it knows if it is empty or not.
    
    
    the relations between tiles and the entities that are stuck in a tile must be preserved when copying tiles or tilemaps
    
    lowest sorted 'entity in tile controls behaviour of block on hit
    unless the block is flagged as 'release all at once' in which case all entities are just thrown out simultaneously
    
    
    we will need quite a bit of new code to manage entities inside tiles and remove them when th etile they belong to is destroyed
    this potentially creates a problem for implementing an undo button for the editor in the future
*/

make_block_hit_event :: (
    tilemap_index:  int,
    tile_index:     int,
    bump_direction: Direction
) -> Event {
    return .{
        timestamp  = get_active_level().ticks_since_start,
        event_type = .BLOCK_HIT,
        tile_event = .{
            tilemap_index  = tilemap_index,
            tile_index     = tile_index,
            bump_direction = bump_direction
        },
    };
}

process_block_hit_event :: (event: Event) {
    assert(event.event_type == .BLOCK_HIT);
    
    level   := get_active_level();
    tilemap := *level.tilemaps[event.tile_event.tilemap_index];
    tile    := *tilemap.data[event.tile_event.tile_index];
    
    entities_in_tile := get_entities_in_tile(level, tile.serial, sort = true);
    if !entities_in_tile {
        // TODO: spawn some little smoke particle to show that tile is empty
        // probably don't do that here, but let tile do it in update_tilemap
        // only thing is, there it doesnt know if it was initially empty or not...
        tile.flags |= .EMPTY;
        return;
    }
    
    // when we release an entity, we will need to un-flag it as being in the tile
    // becuase of this, we could also choose to have some entity like 'timed coins' which will not remove itself until the timer is expired or will continually spawn other entitites
    
    // TODO: make block eject velocity a constant somewhere...
    //       or maybe we want that to be a variable on the entity?
    
    default_physics := *player_templates[0].physics; // @Hack put in temporarily since we are removing default_player_physics
    eject_velocity := compute_jump_force(1.0, default_physics.jump_gravity);
    
    item_spawn_position := get_tile_position(tilemap, event.tile_event.tile_index, .{ 0.5, -0.5 });//direction_vectors[bump_dir] + .{ 0.5, 0.5 });
    if (tile.flags & .RELEASE_ALL_AT_ONCE) && (entities_in_tile.count > 1) {
        base_angle := direction_angles[Direction.U] * PI / 180.0; // TODO: use surface angle for tilemap, also probably based on bump dir
        // print("% %\n", base_angle, unit_vector_given_angle(base_angle));
        
        // speed at which items are ejected and spread of items get greater as we add more items, to a limit
        velocity_scalar := lerp(1.0,  3.0, min(entities_in_tile.count, 50).(float) / 50.0);
        spread          := lerp(0.0, 30.0, min(entities_in_tile.count, 10).(float) / 10.0) * PI / 180;
        
        min_angle := base_angle - spread;
        max_angle := base_angle + spread;
        
        for entities_in_tile {
            it.entity_flags &= ~.IN_BLOCK;
            
            angle_lerp := it_index.(float) / (entities_in_tile.count-1).(float);
            angle      := lerp(min_angle, max_angle, angle_lerp);
            unit_vec   := unit_vector_given_angle(angle);
            
            it.position = item_spawn_position;
            it.velocity = eject_velocity * velocity_scalar * unit_vec;
        }
        
        tile.flags |= .EMPTY;
    } else {
        first := entities_in_tile[0];
        did_remove_entity := false;
        
        if (first.entity_type == .ITEM) && (first.(*Item).item_type == .COIN) {
            item := first.(*Item);
            item.in_block.multi_entity = max(item.in_block.multi_entity - 1, 0);
            
            award_coins(*level.player, 1);
            spawn_coin_particle(item_spawn_position);
            
            if item.in_block.multi_entity == 0 {
                item.entity_flags &= ~.IN_BLOCK;
                item.entity_flags |= .REMOVE_ME;
                did_remove_entity = true;
            }
        } else {
            base_angle := direction_angles[Direction.U] * PI / 180.0; // TODO: use surface angle for tilemap, also probably based on bump dir
            unit_vec   := unit_vector_given_angle(base_angle);
            
            first.entity_flags &= ~.IN_BLOCK;
            first.position = item_spawn_position;
            first.velocity = eject_velocity * unit_vec;
            
            did_remove_entity = true;
        }
        
        if did_remove_entity && entities_in_tile.count == 1 then tile.flags |= .EMPTY;
    }
}

get_entities_in_tile :: (level: *Level_Layout, tile_serial: u32, sort := false) -> [..] *Entity {
    entities_in_tile: [..] *Entity;
    entities_in_tile.allocator = temp;
    for *level.entities {
        if !(it.entity_flags & .IN_BLOCK)   continue;
        if it.in_block.tile_serial != tile_serial  continue;
        array_add(*entities_in_tile, it);
    }
    if sort {
        quick_sort(entities_in_tile, (a, b) => a.in_block.sort_order - b.in_block.sort_order);
    }
    return entities_in_tile;
}

make_block_destroyed_event :: (
    tilemap_index:  int,
    tile_index:     int
) -> Event {
    return .{
        timestamp  = get_active_level().ticks_since_start,
        event_type = .BLOCK_DESTROYED,
        tile_event = .{
            tilemap_index = tilemap_index,
            tile_index    = tile_index,
        },
    };
}

// also called when tile is deleted in editor
process_block_destroyed_event :: (event: Event) {
    assert(event.event_type == .BLOCK_DESTROYED);
    
    level   := get_active_level();
    tilemap := *level.tilemaps[event.tile_event.tilemap_index];
    tile    := *tilemap.data[event.tile_event.tile_index];
    
    for *level.entities {
        if !(it.entity_flags & .IN_BLOCK)   continue;
        if it.in_block.tile_serial != tile.serial  continue;
        deinit_entity(it);
    }
}