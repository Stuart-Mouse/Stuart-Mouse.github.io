/*
    TODO: need to do some restructuring on this probably, to better suit what we're actually doing in this particualr game.
    
    
*/

Event_Type :: enum {
    BLOCK_HIT;
    BLOCK_DESTROYED;
    WARP;
}

Event :: struct {
    timestamp:  u64; // updates since level init
    event_type: Event_Type;
    
    // using a union for now so that we cna just have a dynamic array for events
    // maybe later we will refactor so that events are stored in some arena and cna be of various sizes, then use pointer casting for subtype
    using data: union {
        tile_event: struct {
            tilemap_index:      int;
            tile_index:         int;
            bump_direction:     Direction;
        }
        warp_event: struct {
            warp_locator:       Warp_Locator;
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
      case .WARP;             process_warp_event(event);
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
    
}

get_entities_in_tile :: (level: *Level_Layout, tile_serial: u32, sort := false) -> [] *Entity {
    entities_in_tile: [..] *Entity;
    entities_in_tile.allocator = temp;
    // for *level.entities {
    //     if !(it.flags & .IN_BLOCK)   continue;
    //     if it.in_block.tile_serial != tile_serial  continue;
    //     array_add(*entities_in_tile, it);
    // }
    // if sort {
    //     quick_sort(entities_in_tile, (a, b) => a.in_block.sort_order - b.in_block.sort_order);
    // }
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
    
}

make_warp_event :: (warp_locator: Warp_Locator) {
    return .{
        timestamp  = get_active_level().ticks_since_start,
        event_type = .BLOCK_DESTROYED,
        tile_event = .{
            tilemap_index = tilemap_index,
            tile_index    = tile_index,
        },
    };
}

// similar to begin_area_with_warp, but instead of warping to a new area immediately, we just kick off a scene transition
process_warp_event :: () {
    locator  := Game.warp_event.locator;
    level_id := find_warp_destination(locator);
    // log("Info: Warping to: % @ %", locator.local_id, to_string(locator.level_name.data));
    
    // If warp destination is within the same level, we don't reload.
    // Just find the warp by local id and teleport the player there.
    if !Game.warp_event.force_reload && level_id == Game.active_level.id {
        warp_entity := find_warp_entity_by_id(context.current_level, locator.local_id);
        if warp_entity  begin_exiting_warp(*Game.player, warp_entity);
        return;
    }
    
    // else the warp is going to initiate a scene transition...
    Game.event_flags |= .SCENE_TRANSITION;
    Game.scene_transition = .{ 
        src_scene = .LEVEL, 
        dst_scene = .LEVEL, 
        clock     = (Scene_Transition.TRANSITION_FADE_TIME * updates_per_second).(int)
    };
    
    // put the warp event flag back on, will finish processing it when scene transition is done fading out.
    Game.event_flags |= .WARP;
    Game.warp_event.force_reload = true;
}
