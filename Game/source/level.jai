
// We very often need access to the current level in order to handle even menial things 
// like removing a tile from a tilemap, since there are cross-cutting concerns like notifying 
// entities (which may be flagged as being inside a block) that that block has been destroyed.
// So the current level gets set in the context by the main update loops of the game and editor.
#add_context current_level: *Level_Layout;

Level_ID :: Static_String(16);

// members that are common to Level_Layout and Level_Layout_File
// if this struct is changed, make sure to bump version in Level_Layout_File
Level_Layout_Base :: struct {
    name:                   [32] u8;    // can override in worldmap.lsd
    script_path:            [32] u8;    // can override in worldmap.lsd
    music_path:             [32] u8;    // can override in worldmap.lsd
    bounds:                 Rectf;
    bg_color:               Color4 = .{ 0.2, 0.2, 0.2, 1 };
    player_debug_spawn:     Vector2;
    screen_wrap_up:         Screen_Wrap_Mode;
    screen_wrap_down:       Screen_Wrap_Mode;
    screen_wrap_left:       Screen_Wrap_Mode;
    screen_wrap_right:      Screen_Wrap_Mode;
    tempo:                  float;
    entity_groups:          Static_Array(16, Static_String(16));
    script_random_seed:     u64;
}

Screen_Wrap_Mode :: enum {
    LEVEL_TRANSITION;
    NONE;
    WRAP;
    KILL;
}

// level data as it's stored at runtime
Level_Layout :: struct {
    using base:                 Level_Layout_Base;
    camera:                     Vector2;
    tilemaps:                   [..] Tilemap;
    entities:                   Slot_Array(Entity, 256);
    // event_queue:                Event_Queue;
    
    particles: struct {
        back:                   Slot_Array(Particle, 256);
        middle:                 Slot_Array(Particle, 256);
        front:                  Slot_Array(Particle, 256);
    }
    
    // particle_emitters:  Slot_Array(Particle, 64);
    
    script_source:              string;
    script:                     LS.Script;
    script_random_state:        Random_State;
    
    ticks_since_start:          u32;    // game upate ticks, not milliseconds
    time_since_start:           float;
    
    start_time_absolute:        float;
    
    show_level_script_imgui:    bool;   // TODO: either fix or remove
    cloud_spawn_time:           float;
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

STANDARD_LEVEL_DIMENSIONS :: Vec2f.{ 40, 28 };

// TODO: where/how to store saved state for a level? will have to create some new struct and also store that data out to file

init_empty_level :: (level: *Level_Layout) {
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
    warp_entity := find_warp_entity_by_id(context.current_level, locator.local_id);
    if warp_entity  begin_exiting_warp(*Game.player, warp_entity);
    
    update_camera(0);
}

begin_level_with_id :: (id: string) -> bool {    
    if Game.active_level.info_index == -1 {
        log("Warning: Unable to find level info for level: \"%\"", id);
    }
    
    Game.active_level.map_index = get_map_index_from_level_name(Game.worldmap, id);
    if Game.active_level.map_index == Worldmap.INVALID_MAP_INDEX {
        log("Warning: Unable to find map location for level: \"%\"", id);
    }
    
    layout := *Game.active_level.layout;
    
    // try to find layout in loaded_levels table
    // load it and add to table if not already loaded
    // TODO: need some mechanism to check if loaded level gets overwritten on disk
    //       also need some way to tell if loaded level has been saved since being modified by editor
    found, source_layout := table_find_new(*Game.loaded_level_layouts, id);
    if !found {
        log("level % not found, loading now...", id);
        source_layout = New(Level_Layout);
        if !load_level(source_layout, id) {
            deinit_level(source_layout);
            free(source_layout);
            return false;
        }
        table_add(*Game.loaded_level_layouts, copy_string(id), source_layout);
    }
    
    deinit_level(layout);
    clone_level(layout, source_layout);
    
    // currently using the script and music paths on the layout
    // TODO: use the paths in the worldmap file instead once all that is working properly
    // TODO: info in the worldmap file should be treated as on override, still using the paths in the level file itself when no info can be located
    
    script_path := to_string(*layout.script_path[0]);
    load_level_script(layout, script_path);
    
    music_path := to_string(*layout.music_path[0]);
    if music_path  load_and_play_music(music_path);
    
    prep_level(layout);
    
    saved_state := get_level_saved_state(id);
    if saved_state {
        restore_saved_level_state(layout, saved_state);
    }
    
    copy_from_string(*Game.active_level.id, id);
    Game.active_level.info_index = get_level_info_index(Game.worldmap, id);

    return true;
}

prep_level :: (level: *Level_Layout) {
    level.ticks_since_start = 0;
    level.time_since_start  = 0;
    level.cloud_spawn_time  = 0;
    
    level.start_time_absolute = seconds_since_init().(float);
    
    for *level.tilemaps {
        it.offset_next = it.root_offset;
    }
    
    for *level.entities {
        prep_entity(it);
    }
    
    // TODO: need some flags to control whether we actually do this
    level.script_random_seed = random_get();
    
    if level.script.flags & .TYPECHECKED {
        init_block := LS.get_named_block(*level.script, "init");
        if init_block {
            random_seed(*level.script_random_state, level.script_random_seed);
            defer_restore(*context.random_state);
            context.random_state = level.script_random_state;
            
            level.script.stack_ptr = level.script.stack_base;
            if !LS.execute_node(*level.script, init_block, explicit_call = true) {
                log("Error: failed to execute script update!");
                log(LS.format_error(*level.script.error));
            }
        }
    }
    
    // update twice so that we don't just calc next state
    for 0..1 {
        for *level.tilemaps  update_tilemap_prescript(it);
        execute_level_script(level);
        for *level.tilemaps  update_tilemap_postscript(it);
    }
    
    init_all_entity_handles(level);
    init_player_for_new_level(*Game.player, level);
    
}

load_level_script :: (level: *Level_Layout, source_path: string) -> bool {
    using LS;
    free_script(*level.script);
    free(level.script_source);
    
    if !source_path  return true;
    
    source, ok := read_entire_file(join("data/scripts/", source_path,, temp));
    if !ok {
        log("Unable to load script source file: '%'!", source_path);
        return false;
    }
    level.script_source = source;
    
    init_script(*level.script);
    
    register_type(*level.script, "bool",    type_info(bool));
    register_type(*level.script, "float",   type_info(float));
    register_type(*level.script, "int",     type_info(int));
    register_type(*level.script, "Vector2", type_info(Vector2));
    
    register_procedure(*level.script, "entity_group", #procedure_of_call get_all_entities_in_group(0));
    register_procedure(*level.script, "entity_group", #procedure_of_call get_all_entities_in_group(""));
    register_procedure(*level.script, "default_position", (entity: *Entity) -> Vec2f { 
        position := entity.init_position;
        if entity.flags & .ATTACHED_TO_TILEMAP 
            position += get_tilemap_offset_from_root(context.current_level.tilemaps[entity.attached_index]); 
        
        // TODO: this raises potential issues with order in which entities are updated
        else if entity.flags & .ATTACHED_TO_ENTITY
            position += context.current_level.entities[entity.attached_index].position;
        
        return position;
    });
    
    register_procedure(*level.script, "offset_from_root", get_tilemap_offset_from_root);
    
    register_procedure(*level.script, "fmod", #procedure_of_call fmod_cycling(1, 1));
    register_procedure(*level.script, "pow", pow);
    register_procedure(*level.script, "sin", sin);
    register_procedure(*level.script, "cos", cos);
    register_procedure(*level.script, "random_bool", () -> bool { return (random_get() & 1).(bool); });
    register_procedure(*level.script, "random_int", (min: int, max: int) -> int { return min + (xx random_get() % (max-min+1)); });
    register_procedure(*level.script, "random_float", #procedure_of_call random_get_within_range(.0, .0));
    
    // TODO: support passing Any in scripts
    echo :: (t: $T) -> T { print("%\n", t); return t; };
    register_procedure(*level.script, "echo", #procedure_of_call echo(1.0));
    register_procedure(*level.script, "echo", #procedure_of_call echo(1));
    register_procedure(*level.script, "echo", #procedure_of_call echo(Vector2.{}));
    
    register_procedure(*level.script, "cycle_over", (value: float, divisor: float) -> float { return fmod_cycling(value, divisor) / divisor; });
    
    register_procedure(*level.script, "circle", (lerp: float, phase: float) -> Vector2 { return .{ cos(lerp * 2 * PI), sin((lerp + phase) * 2 * PI) }; });
    register_procedure(*level.script, "ellipse", (lerp: float, x_timescale: float, y_timescale: float, phase: float) -> Vector2 { return .{ cos(lerp * x_timescale * 2 * PI), sin((lerp + phase) * y_timescale * 2 * PI) }; });
    register_procedure(*level.script, "rotate", #procedure_of_call rotate(Vector2.{}, 1.0));
    
    register_procedure(*level.script, "Xfloat", (id: string, v: *float) { 
        if context.current_level.show_level_script_imgui {
            // imgui.InputFloat(temp_c_string(id), v);
        }
    });
    
    set_script_variables(level);
    
    if !parse_source_file(*level.script, level.script_source, source_path) {
        log("Error: Failed to construct script from source!\n");
        log(format_error(level.script.error));
        free_script(*level.script);
        free(level.script_source);
        level.script_source = "";
        level.script = .{};
        return false;
    }
    
    return true;
}

execute_level_script :: (level: *Level_Layout, show_imgui := false) {
    defer_restore(*context.current_level);
    context.current_level = level;
    
    random_seed(*level.script_random_state, level.script_random_seed);
    defer_restore(*context.random_state);
    context.random_state = level.script_random_state;
    
    if show_imgui {
        // imgui.Begin("Level Script");
        // level.show_level_script_imgui = true;
    }
    if level.script.flags & .TYPECHECKED {
        if !LS.execute_script(*level.script) {
            log("Error: failed to execute script update!");
            log(LS.format_error(*level.script.error));
        }
    }
    if show_imgui {
        // imgui.End();
        // level.show_level_script_imgui = false;
    }
}

set_script_variables :: (level: *Level_Layout) {
    // TODO: we should check that all tilemaps and other named entities in a level have unique names
    LS.set_variable(*level.script, "time", level.time_since_start);
    for level.tilemaps {
        LS.set_variable(*level.script, to_string(*it.name[0]), it);
    }
    
    LS.set_variable(*level.script, "Game", Game);
    LS.set_variable(*level.script, "player", Game.player);
    LS.set_variable(*level.script, "tilemaps", level.tilemaps);
    
    LS.set_variable(*level.script, "updates_per_second", updates_per_second);
    
    for *level.entities {
        name := to_string(*it.name[0]);
        if name {
            LS.set_variable(*level.script, name, it.data);
        }
    }
}

deinit_level :: (level: *Level_Layout) {
    for *level.entities  deinit_entity(it);
    for *level.tilemaps  free_tilemap(it); 
    array_free(level.tilemaps);
    
    LS.free_script(*level.script);
    free(level.script_source);
    
    level.* = .{};
}

clone_level :: (dst: *Level_Layout, src: *Level_Layout) {
    if dst == null { print("src level was null\n"); return; }
    if src == null { print("dst level was null\n"); return; }
    
    if dst == src {
        print("dst and src were the same?\n");
        return;
    }
    
    dst.base = src.base;
    
    // NOTE: we intentionally do not copy particles, script, script_source
    // script in particular needs to be loaded and initialized separately
    
    dst.entities         = src.entities;
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
    
    FILE_VERSION :: 3; // bump version each time this struct (or Level_Layout_Base) is changed!
}

LEVEL_PATH_FORMAT_STRING           :: "data/levels/%.lvl";
LEVEL_TYPE_INFO_PATH_FORMAT_STRING :: "data/levels/%.lvlti";

save_level :: (level: Level_Layout, name: string) -> bool {
    type_info_file_path := tprint(LEVEL_TYPE_INFO_PATH_FORMAT_STRING, name);
    file_path           := tprint(LEVEL_PATH_FORMAT_STRING,           name);
    
    // TODO: @HACK just remapping tile ids in place, then mapping them back. This is definitely not ideal, but should still be faster than cloning all of the tilemaps...
    for *level.tilemaps  remap_tile_ids_for_storage(it);
    defer for *level.tilemaps  remap_tile_ids_for_runtime(it);
    
    // shallow copy of level data, since we don't want to have to worry about cloning/freeing unnecessarily
    level_file: Level_Layout_File;
    level_file.base = level.base;
    level_file.tilemaps  = array_view(level.tilemaps, 0);
    level_file.entities  = clone_to_view(level.entities);
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
    deinit_level(level);
    level.base = level_file.base;
    level.tilemaps = make_resizable(level_file.tilemaps);
    clone_from_view(*level.entities, level_file.entities);
    
    for *level.tilemaps {
        remap_tile_ids_for_runtime(it);
    }
    
    // @nocheckin HACK remove later!
    for *level.entities {
        if it.init_position.x == 0 then it.init_position = it.position;
        if it.scale.x == 0 then it.scale = .{ 1, 1 };
    }
    
    for *level.tilemaps {
        if it.color_mod.a == 0 then it.color_mod = .{ 1, 1, 1, 1 };
    }
    
    log("Loaded level: %\n", name);
    return true;
}



Level_Saved_State :: struct {
    level_id:   Level_ID;
    
    collected_coins: [..] struct {
        tilemap_index:  int;
        tile_index:     Vec2i;
    };
    
    
}

restore_saved_level_state :: (level: *Level_Layout, saved_state: Level_Saved_State) {
    if ignore_saved_level_state  return;
    
    for saved_state.collected_coins {
        if it.tilemap_index < 0 || it.tilemap_index >= level.tilemaps.count  continue;
        tilemap := *level.tilemaps[it.tilemap_index];
        
        tile := get_tile(tilemap, it.tile_index);
        if !tile  continue;
        
        remove_tile(tile);
    }
}

get_or_add_level_saved_state :: (level_id: string) -> *Level_Saved_State {
    for *Game.saved_level_state {
        if to_string(*it.level_id) == level_id {
            return it;
        }
    }
    
    saved_state := array_add(*Game.saved_level_state);
    copy_from_string(*saved_state.level_id, level_id);
    return saved_state;
}

get_level_saved_state :: (level_id: string) -> *Level_Saved_State {
    for *Game.saved_level_state {
        if to_string(*it.level_id) == level_id {
            return it;
        }
    }
    return null;
}

record_collected_coin :: (tilemap_index: int, tile_index: Vec2i) {
    saved_state := get_or_add_level_saved_state(to_string(*Game.active_level.id));
    if !saved_state {
        log("Error: unable to record collected coin!");
        return;
    }
    
    array_add(*saved_state.collected_coins, .{ tilemap_index, tile_index });
}
