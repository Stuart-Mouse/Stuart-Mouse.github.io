
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