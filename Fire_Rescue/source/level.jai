
// We very often need access to the current level in order to handle even menial things 
// like removing a tile from a tilemap, since there are cross-cutting concerns like notifying 
// entities (which may be flagged as being inside a block) that that block has been destroyed.
// So the current level gets set in the context by the main update loops of the game and editor.
#add_context current_level: *Level_Layout;

// members that are common to Level_Layout and Level_Layout_File
// if this struct is changed, make sure to bump version in Level_Layout_File
Level_Layout_Base :: struct {
    name:           [32] u8;    // TODO: move to worldmap definition
    script_path:    [32] u8;    // TODO: move to worldmap definition
    music_path:     [32] u8;    // TODO: move to worldmap definition
    player:         Player;     // TODO: move to Level_Layout, replace with some spawn warp entity, maybe also add debug spawn entity
    camera:         Vector2;    // TODO: move to Level_Layout
    bounds:         Rectf;
    sky_color:      Color4 = .{ 0.573, 0.565, 1, 1 };
}

// level data as it's stored at runtime
Level_Layout :: struct {
    using base:         Level_Layout_Base;
    tilemaps:           [..] Tilemap;
    entities:           Slot_Array(Entity_Union, 256);
    event_queue:        Event_Queue;
    
    particles: struct {
        back:       Slot_Array(Particle, 256);
        // mid_back:   Slot_Array(Particle, 256);
        // mid_front:  Slot_Array(Particle, 256);
        front:      Slot_Array(Particle, 256);
    }
    
    particle_emitters:  Slot_Array(Particle, 64);
    
    script_source:      string;
    script:             LS.Script;
    
    ticks_since_start:  u32;    // game upate ticks, not milliseconds
    time_since_start:   float;
    
    show_level_script_imgui: bool;
    cloud_spawn_time: float;
};

begin_area_with_warp :: (locator: Warp_Locator) {
    using Game.worldmap;
    
    found, level_index, area_index := find_level_and_area(locator);
    if !found {
        log("Warp destination could not be resolved: %, %, %", locator.local_id, to_string(locator.level_name.data), to_string(locator.area_name.data));
        return;
    }
    log("Warping to: %, %, %", locator.local_id, to_string(locator.level_name.data), to_string(locator.area_name.data));
    
    
    if level_index < 0 || area_index < 0 {
        copy_editor_level_to_active_level();
        return;
    }
    
    Game.last_significant_warp = locator;
    
    active_level = level_index;
    active_area  = area_index;
    
    level := *levels[level_index];
    area  := *level.areas[area_index];
    
    __begin_area(area);
    
    // if we cannot locate the intended warp exit by its local id, we will just spawn the player in the default spawn position
    layout := context.current_level;
    for *layout.entities {
        if it.entity_type == .WARP 
        && it.warp.local_id == locator.local_id {
            begin_exiting_warp(*layout.player, xx it);
            break;
        }
    }
    
    update_camera(0);
}

begin_area :: (level_index: int, area_index: int) {
    using Game.worldmap;
    
    if level_index < 0 || level_index >= levels.count {
        log("Error: Invalid level index: %", level_index);
        return;
    }
    active_level = level_index;
    level := *levels[level_index];
    
    if area_index < 0 || area_index >= level.areas.count {
        log("Error: Invalid area index: %", area_index);
        return;
    }
    active_area = area_index;
    area := *level.areas[area_index];
    
    __begin_area(area);
}

// probably don't use this in 90% of cases, since we want to also set the worldmap active level and active area before loading a new area
__begin_area :: (area: *Level_Info.Area) {
    layout := context.current_level;
    
    if !load_level(layout, area.layout)  return;
    
    // currently using the script and music paths on the layout
    // TODO: use the paths in the worldmap file instead once all that is working properly
    
    script_path := to_string(*layout.script_path[0]);
    load_level_script(layout, script_path);
    
    music_path := to_string(*layout.music_path[0]);
    if music_path  load_and_play_music(music_path);
    
    prep_level(layout);
}

prep_level :: (level: *Level_Layout) {
    level.ticks_since_start = 0;
    level.time_since_start  = 0;
    level.cloud_spawn_time  = 0;
    
    for *level.tilemaps {
        it.offset_next   = it.root_offset;
        it.rotation_next = it.base_rotation;
    }
    
    // update twice so that we don't just calc next state
    for 0..1 {
        for *level.tilemaps  update_tilemap_prescript(it);
        execute_level_script(level);
        for *level.tilemaps  update_tilemap_postscript(it);
    }
    
    init_all_entity_handles(level);
    
    init_player(*level.player);
    snap_player_camera_focus_point(*level.player);
}

load_level_script :: (level: *Level_Layout, source_path: string) -> bool {
    using LS;
    free_script(*level.script);
    free(level.script_source);
    
    if !source_path  return true;
    
    source, ok := read_entire_file(join("data/levels/", source_path,, temp));
    if !ok {
        log("Unable to load script source file: '%'!", source_path);
        return false;
    }
    level.script_source = source;
    
    init_script(*level.script);
    
    register_type(*level.script, "float",   type_info(float));
    register_type(*level.script, "int",     type_info(int));
    register_type(*level.script, "Vector2", type_info(Vector2));
    
    register_procedure(*level.script, "fmod", #procedure_of_call fmod_cycling(1, 1));
    register_procedure(*level.script, "pow", pow);
    register_procedure(*level.script, "sin", sin);
    register_procedure(*level.script, "cos", cos);
    
    echo :: (t: $T) -> T { print("%\n", t); return t; };
    register_procedure(*level.script, "echo", #procedure_of_call echo(1.0));
    register_procedure(*level.script, "echo", #procedure_of_call echo(1));
    register_procedure(*level.script, "echo", #procedure_of_call echo(Vector2.{}));
    
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
        free_script(*level.script);
        free(level.script_source);
        level.script_source = "";
        level.script = .{};
        return false;
    }
    
    return true;
}

set_script_variables :: (level: *Level_Layout) {
    // TODO: we should check that all tilemaps and other named entities in a level have unique names
    LS.set_variable(*level.script, "time", level.time_since_start);
    for level.tilemaps {
        LS.set_variable(*level.script, to_string(*it.name[0]), it);
    }
}

deinit_level :: (level: *Level_Layout) {
    for *level.entities  deinit_entity(it);
    for *level.tilemaps  array_free(it.data); 
    array_free(level.tilemaps);
    
    LS.free_script(*level.script);
    free(level.script_source);
    
    array_reset(*level.event_queue.events);
    
    level.* = .{};
}

clone_level :: (dst: *Level_Layout, src: *Level_Layout) {
    if dst == null { print("src level was null\n"); return; }
    if src == null { print("dst level was null\n"); return; }
    
    if dst == src {
        print("dst and src were the same?\n");
        return;
    }
    
    dst.player      = src.player;
    dst.script_path = src.script_path;
    dst.music_path  = src.music_path;
    dst.camera    = src.camera;
    dst.bounds    = src.bounds;
    dst.entities  = src.entities;
    dst.particles = src.particles;
    dst.sky_color = src.sky_color;
    dst.time_since_start = 0;
    
    clone_tilemap :: (dst: *Tilemap, src: *Tilemap) {
        array_free(dst.data);
        dst.* = .{};
        
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
    entities:   [] Entity_Union;
    
    FILE_VERSION :: 3; // bump version each time this struct (or Level_Layout_Base) is changed!
}

LEVEL_PATH_FORMAT_STRING           :: "data/levels/%.lvl";
LEVEL_TYPE_INFO_PATH_FORMAT_STRING :: "data/levels/%.lvlti";

save_level :: (level: Level_Layout, name: string) -> bool {
    type_info_file_path := tprint(LEVEL_TYPE_INFO_PATH_FORMAT_STRING, name);
    file_path           := tprint(LEVEL_PATH_FORMAT_STRING,           name);
    
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
        log("Info: failed to load level. failed to read type info file");
        return false;
    }
    defer free(info_file);
    
    info := Data_Packer.unpack_type_info_with_header(xx info_file, base_type_info);
    if !info {
        log("Info: failed to load level. failed to unpack type info");
        return false;
    }
    
    if !Data_Packer.unpack_file_with_type_info(file_path, info, level_file) {
        log("Failed to load level: %\n", name);
        return false;
    }
    
    // copy everything back to runtime level data
    deinit_level(level);
    level.base = level_file.base;
    level.tilemaps = make_resizable(level_file.tilemaps);
    clone_from_view(*level.entities, level_file.entities);
    
    log("Loaded level: %\n", name);
    return true;
}