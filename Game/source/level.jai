
// We very often need access to the current level in order to handle even menial things 
// like removing a tile from a tilemap, since there are cross-cutting concerns like notifying 
// entities (which may be flagged as being inside a block) that that block has been destroyed.
// So the current level gets set in the context by the main update loops of the game and editor.
#add_context current_level: *Level;

Level_ID :: Static_String(16);

Level :: struct {
    using layout:       *Level_Layout;
    script:             Level_Script;
    
    id:                 Level_ID;
    map_index:          Vec2i       = Worldmap.INVALID_MAP_INDEX;
    info_index:         int         = -1;
    saved_state_index:  int         = -1;
}

// members that are common to Level_Layout and Level_Layout_File
// if this struct is changed, make sure to bump version in Level_Layout_File

// TODO: consider replacing static sized arrays and char buffers here with views/strings
//       then move those to Level_Layout_File and use a more flexible structure at runtime, such as resizable arrays, sort of like we do for tilemaps and entities
//       this will require more remapping when we go from runtime -> storage and vice versa, but these should also be pretty trivial remappings anyways
//       also, wait to do all this until we have proper versioning on level files and don't duplicate all the type info files
Level_Layout_Base :: struct {
    name:                   Static_String(32);
    script_path:            Static_String(32);
    music_path:             Static_String(32);
    bounds:                 Rectf;
    bg_color:               Color4 = .{ 0.2, 0.2, 0.2, 1 };
    player_debug_spawn:     Vector2;
    screen_wrap_up:         Screen_Wrap_Mode;
    screen_wrap_down:       Screen_Wrap_Mode;
    screen_wrap_left:       Screen_Wrap_Mode;
    screen_wrap_right:      Screen_Wrap_Mode;
    tempo:                  float;
}

Screen_Wrap_Mode :: enum u8 {
    NONE;
    LEVEL_TRANSITION;
    WRAP;
    KILL;
}

// level data as it's stored at runtime
Level_Layout :: struct {
    using base:                 Level_Layout_Base;
    camera:                     Vector2;
    tilemaps:                   [..] Tilemap;
    entities:                   Slot_Array(Entity, 256);
    entity_groups:              Slot_Array(Entity_Group, MAX_ENTITY_GROUPS);
    // event_queue:                Event_Queue;
    
    particles: struct {
        back:                   Slot_Array(Particle, 256);
        middle:                 Slot_Array(Particle, 256);
        front:                  Slot_Array(Particle, 256);
    }
    
    // particle_emitters:  Slot_Array(Particle, 64);
    
    ticks_since_start:          u32;    // game upate ticks, not milliseconds
    time_since_start:           float;
    
    start_time_absolute:        float;
    
    cloud_spawn_time:           float;  // TODO: remove, create particle spawner entities that are configurable
};

// NOTE: when/if we add back in the idea of multiple areas within a level, 
//       we will actually leave 'level' as the basic unit, then create some sort of 'level group' which encompases multiple levels
//       perhaps we will even use the name Area again, but reversing the relationship between Level and Area
Level_Info :: struct {
    id:                 string;
    name:               string;
    script_path:        string;
    music_path:         string;
    
    // TODO: add overrides for assets, music, color palettes, tilemaps, etc
}


// TODO: once we have proper versioning, don't save type info for every single level like a dummy.
// But doing this caveman style for now, because i was even more grug brained before and didnt think about the fact that I was saving over my previous level ti files...

// Level_Layout_File_Header :: struct {
//     header_version: int;
//     file_version:   int;
// }

// level data as it is serialized to file
// we remap this to/from the runtime Level_Layout struct
Level_Layout_File :: struct {
    using base: Level_Layout_Base;
    tilemaps:   [] Tilemap;
    entities:   [] Entity;
    entity_groups:     [] Entity_Group;
    
    FILE_VERSION :: 3; // bump version each time this struct (or Level_Layout_Base) is changed!
}


STANDARD_LEVEL_DIMENSIONS :: Vec2f.{ 40, 28 };

init_empty_level_layout :: (level: *Level_Layout) {
    level.bounds = .{ size = STANDARD_LEVEL_DIMENSIONS };
    array_add(*level.tilemaps, .{});
    tilemap := *level.tilemaps[0];
    
    init_tilemap(tilemap);
    tilemap.root_offset = .{ level.bounds.x, level.bounds.h - 2 };
    coord := Vec2i.{ 0, 0 };
    for 0..level.bounds.w.(int)-1 {
        coord = place_tile(tilemap, Tile.{ id = 1 }, coord);
        coord += .{  0,  1 };
        coord = place_tile(tilemap, Tile.{ id = 1 }, coord);
        coord += .{  1, -1 };
    }
    level.player_debug_spawn = .{ 20, 24 };
}

begin_level_with_warp :: (locator: Warp_Locator) {
    level_name := to_string(*locator.level_name);
    
    id := find_warp_destination(locator);
    // log("Warping to: % @ %", locator.local_id, level_name);
    
    begin_level_with_id(id);
    Game.checkpoint = .{ warp_locator = locator };
    
    // if we cannot locate the intended warp exit by its local id, 
    // then we will just spawn the player in the debug spawn position
    // TODO: maybe log a warning here if the exit warp entity is not found
    warp_entity := find_warp_entity_by_id(Game.active_level.layout, locator.local_id);
    if warp_entity  begin_exiting_warp(*Game.player, warp_entity);
    
    update_camera(0);
}

begin_level_with_id :: (_id: string, use_debug_spawn := false) -> bool {
    using Game.active_level;
    
    if info_index == -1 {
        // log("Warning: Unable to find level info for level: \"%\"", id);
    }
    
    map_index = get_map_index_from_level_name(Game.worldmap, _id);
    if map_index == Worldmap.INVALID_MAP_INDEX {
        // log("Warning: Unable to find map location for level: \"%\"", id);
    }
    
    // try to find layout in loaded_levels table
    // load it and add to table if not already loaded
    // TODO: need some mechanism to check if loaded level gets overwritten on disk
    //       also need some way to tell if loaded level has been saved since being modified by editor
    found, source_layout := table_find_new(*Game.loaded_level_layouts, _id);
    if !found {
        source_layout = New(Level_Layout);
        if !load_level(source_layout, _id) {
            deinit_level_layout(source_layout);
            free(source_layout);
            return false;
        }
        table_add(*Game.loaded_level_layouts, copy_string(_id), source_layout);
    }
    
    deinit_level_layout(layout);
    clone_level_layout(layout, source_layout);
    
    // currently using the script and music paths on the layout
    // TODO: use the paths in the worldmap file instead once all that is working properly
    // TODO: info in the worldmap file should be treated as on override, still using the paths in the level file itself when no info can be located
    
    _script_path := to_string(*layout.script_path[0]);
    load_level_script(*Game.active_level, _script_path);
    
    _music_path := to_string(*layout.music_path[0]);
    if _music_path  load_and_play_music(_music_path);
    
    prep_level(*Game.active_level);
    
    saved_state := get_saved_level_state(_id);
    if saved_state {
        restore_saved_level_state(layout, saved_state);
    }
    
    copy_from_string(*id, _id);
    info_index = get_level_info_index(Game.worldmap, _id);
    
    if use_debug_spawn {
        set_checkpoint(.{ level_name = id }, .USE_DEBUG_SPAWN);
    }

    return true;
}

prep_level :: (using level: *Level) {
    layout.ticks_since_start = 0;
    layout.time_since_start  = 0;
    layout.cloud_spawn_time  = 0;
    
    layout.start_time_absolute = seconds_since_init().(float);
    
    for *layout.tilemaps {
        it.offset_next = it.root_offset;
    }
    
    for *layout.entities {
        prep_entity(it);
    }
    
    // TODO: need some flags to control whether we actually do this
    script.random_seed = random_get();
    
    execute_level_script_init_block(level);
    
    // update twice so that we don't just calc next state
    for 0..1 {
        for *layout.tilemaps  update_tilemap_prescript(it);
        execute_level_script(level);
        for *layout.tilemaps  update_tilemap_postscript(it);
    }
    
    init_all_entity_handles(layout);
    init_player_for_new_level(*Game.player, layout);
    
    for *layout.entities {
        if it.flags & .SNAP_TO_FLOOR_ON_LEVEL_INIT then snap_to_floor(it);
    }
}

deinit_level_layout :: (level: *Level_Layout) {
    for *level.entities  deinit_entity(it);
    for *level.tilemaps  free_tilemap(it); 
    array_free(level.tilemaps);
    
    level.* = .{};
}

clone_level_layout :: (dst: *Level_Layout, src: *Level_Layout) {
    deinit_level_layout(dst);
    
    dst.base             = src.base;
    dst.entities         = src.entities;
    dst.entity_groups    = src.entity_groups;
    dst.time_since_start = 0;
    
    clone_tilemap :: (dst: *Tilemap, src: *Tilemap) {
        if !src.data { 
            print("src tilemap data was null!\n");
            return;
        }
        dst.*    = src.*;
        dst.data = array_copy(src.data);
    }
    
    array_reserve(*dst.tilemaps, src.tilemaps.count);
    dst.tilemaps.count = src.tilemaps.count;
    for *src.tilemaps  clone_tilemap(*dst.tilemaps[it_index], it);
}






LEVEL_PATH_FORMAT_STRING           :: "data/levels/%.lvl";
LEVEL_TYPE_INFO_PATH_FORMAT_STRING :: "data/levels/%.lvlti";

save_level :: (level: Level_Layout, name: string) -> bool {
    type_info_file_path := tprint(LEVEL_TYPE_INFO_PATH_FORMAT_STRING, name);
    file_path           := tprint(LEVEL_PATH_FORMAT_STRING,           name);
    
    // TODO: @HACK just remapping tile ids in place, then mapping them back. This is definitely not ideal, but should still be faster than cloning all of the tilemaps...
    for *level.tilemaps  remap_tile_ids_for_storage(it);
    defer for *level.tilemaps  remap_tile_ids_for_runtime(it);
    
    for *level.entities  remap_entity_template_id_for_storage(it);
    defer for *level.entities  remap_entity_template_id_for_runtime(it);
    
    // shallow copy of level data, since we don't want to have to worry about cloning/freeing unnecessarily
    level_file: Level_Layout_File;
    level_file.base = level.base;
    level_file.tilemaps  = array_view(level.tilemaps, 0);
    level_file.entities  = clone_to_view(level.entities);
    level_file.entity_groups    = clone_to_view(level.entity_groups);
    defer array_free(level_file.entities);
    
    if !Data_Packer.pack_file_with_type_info(file_path, type_info_file_path, level_file) {
        log("Failed to save level: %\n", name);
        return false;
    }
    log("Saved level: %\n", name);
    
    return true;
}

load_level :: (level: *Level_Layout, name: string, base_type_info := type_info(*Type_Info)) -> bool {
    type_info_file_path := tprint(LEVEL_TYPE_INFO_PATH_FORMAT_STRING, name);
    file_path           := tprint(LEVEL_PATH_FORMAT_STRING,           name);
    
    level_file: Level_Layout_File;
    defer {
        array_free(level_file.entities);
        // we don't free tilemaps, since ownership is taken by level
    }
    
    info_file, ok := read_entire_file(type_info_file_path);
    if !ok {
        log("Error: failed to load level, unable to load type info file: %", type_info_file_path);
        return false;
    }
    defer free(info_file);
    
    info := Data_Packer.unpack_type_info_with_header(xx info_file, base_type_info);
    if !info {
        log("Error: failed to load level, unable to unpack type info file: %", file_path);
        return false;
    }
    
    if !Data_Packer.unpack_file_with_type_info(file_path, info, level_file) {
        log("Error: Failed to load level: %\n", name);
        return false;
    }
    
    // copy everything back to runtime level data
    deinit_level_layout(level);
    level.base = level_file.base;
    level.tilemaps = make_resizable(level_file.tilemaps);
    if !clone_from_view(*level.entities, level_file.entities) {
        log("Warning: unable to copy entities array from level file to runtime level struct!");
    }
    if !clone_from_view(*level.entity_groups, level_file.entity_groups) {
        log("Warning: unable to copy entities array from level file to runtime level struct!");
    }
    
    for *level.tilemaps  remap_tile_ids_for_runtime(it);
    for *level.entities  remap_entity_template_id_for_runtime(it);
    
    // fix invalid entity member values
    for *level.entities {
        prep_entity(it);
    }
    
    if level.tempo == 0 then level.tempo = 1;
    
    // NOTE: this does not affect generation currently, so this just ensures that all reported indices match reailty
    init_all_entity_handles(level);
    
    for *level.tilemaps {
        if it.color_mod.a == 0 then it.color_mod = .{ 1, 1, 1, 1 };
    }
    
    return true;
}


/*
    Saved Level State
    
    Whenever the player causes some change in a level that needs to be stored as persistent state,
    we create a Saved_Level_State.Entry that describes the modification, as well as hte conditions to commit or revert the change.
    
    Committing a change entails that this change will be stored to the player's save file.
    A change can still be reverted after being committed. (For example, we commit the collection of coins immediately, but this will still be reverted upon a game over.)
*/

Saved_Level_State :: struct {
    level_id:   Level_ID;
    entries:    [..] Entry;
    
    // used for pending changes which game may revert or commit on e.g. player death, game over, checkpoint acquired, etc.
    Entry :: struct {
        state:      enum { UNCOMMITTED :: 0; COMMITTED :: 1; };
        
        commit_condition:   Revert_Or_Commit_Condition;
        revert_condition:   Revert_Or_Commit_Condition;
        
        commit_flags:       Revert_Or_Commit_Flags;
        revert_flags:       Revert_Or_Commit_Flags;
        
        Kind :: enum {
            MODIFIED_TILE;
            MODIFIED_ENTITY;
        };
        kind: Kind;
        
        union {
            modified_tile:      Modified_Tile;
            modified_entity:    Modified_Entity;
        }
    }
    
    Revert_Or_Commit_Condition :: enum { 
        IMMEDIATE; 
        PLAYER_DEATH; 
        GAME_OVER; 
        SET_CHECKPOINT; 
        LOAD_CHECKPOINT; 
    };
    
    Revert_Or_Commit_Flags :: enum_flags { 
        AWARD_PLAYER_HEART_CONTAINER; 
    };
    
    Modified_Tile :: struct {
        tilemap_index:  int;
        tile_index:     Vec2i; // TODO: maybe replace with serial number? Need to check if resizing tilemap affects saved state
        tile_state:     Tile;
    }
    
    Modified_Entity :: struct {
        entity_handle:  Entity_Handle;  // NOTE: alternatively, could use entity name
        entity_state:   Entity;
    }
}

restore_saved_level_state :: (level: *Level_Layout, saved_state: Saved_Level_State) {
    if ignore_saved_level_state  return;
    
    for *saved_state.entries {
        if it.kind == {
          case .MODIFIED_TILE;
            if it.modified_tile.tilemap_index < 0 || it.modified_tile.tilemap_index >= level.tilemaps.count  continue;
            tilemap := *level.tilemaps[it.modified_tile.tilemap_index];
            
            actual_tile_index := tilemap.root_index + it.modified_tile.tile_index;
            
            tile := get_tile(tilemap, actual_tile_index);
            if tile then tile.* = it.modified_tile.tile_state;
        
          case .MODIFIED_ENTITY;
            // TODO
        }
    }
}

get_or_add_saved_level_state :: (level_id: string) -> *Saved_Level_State {
    for *Game.saved_level_state {
        if to_string(*it.level_id) == level_id {
            return it;
        }
    }
    
    saved_state := array_add(*Game.saved_level_state);
    copy_from_string(*saved_state.level_id, level_id);
    return saved_state;
}

get_saved_level_state :: (level_id: string) -> *Saved_Level_State {
    for *Game.saved_level_state {
        if to_string(*it.level_id) == level_id {
            return it;
        }
    }
    return null;
}

record_saved_level_state :: (level_id: Level_ID, entry: Saved_Level_State.Entry) {
    saved_state := get_or_add_saved_level_state(to_string(*Game.active_level.id));
    if !saved_state {
        log("Error: unable to record collected coin!");
        return;
    }
    
    new_entry := array_add(*saved_state.entries);
    new_entry.* = entry;
    
    if new_entry.commit_condition == .IMMEDIATE {
        commit_saved_level_state(new_entry);
        return;
    }
}

commit_saved_level_state :: (entry: *Saved_Level_State.Entry) {
    entry.state = .COMMITTED;
    
    if entry.commit_flags & .AWARD_PLAYER_HEART_CONTAINER {
        // TODO
    }
}

revert_saved_level_state :: (entry: Saved_Level_State.Entry) {
    // NOTE: we don't really undo anything special in the level state of any levels at the current time.
}

commit_or_revert_pending_saved_level_state :: (condition: Saved_Level_State.Revert_Or_Commit_Condition) {
    for *Game.saved_level_state {
        index := 0;
        while index < it.entries.count {
            entry := *it.entries[index];
            if entry.commit_condition == condition {
                commit_saved_level_state(entry);
                continue;
            }
            if entry.revert_condition == condition {
                revert_saved_level_state(entry);
                array_unordered_remove_by_index(*it.entries, index);
                continue;
            }
            index += 1;
        }
    }
}

record_collected_coin :: (tilemap_index: int, tile_index: Vec2i) {
    if tilemap_index < 0 || tilemap_index >= context.current_level.tilemaps.count  return;
    tilemap := *context.current_level.tilemaps[tilemap_index];
    persistent_tile_index := tile_index - tilemap.root_index;
    
    record_saved_level_state(Game.active_level.id, .{
        commit_condition = .IMMEDIATE,
        revert_condition = .GAME_OVER,
        kind = .MODIFIED_TILE,
        modified_tile = .{
            tilemap_index   = tilemap_index,
            tile_index      = persistent_tile_index,
            tile_state      = .{},
        }
    });
}
