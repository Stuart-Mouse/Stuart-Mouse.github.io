

// TODO: once we have proper versioning, don't save type info for every single level like a dummy.
// But doing this caveman style for now, because i was even more grug brained before and didnt think about the fact that I was saving over my previous level ti files...

// Level_Layout_File_Header :: struct {
//     header_version: int;
//     file_version:   int;
// }

// level data as it is serialized to file
// we remap this to/from the runtime Level_Layout struct
Level_Layout_File :: struct {
    using base:         Level_Layout_Base;
    tilemaps:           [] Tilemap_File;
    entities:           [] Entity_File;
    entity_groups:      [] Entity_Group;
    
    // or should virtual members be part of level saved state? maybe just for override values?
    // virtual_members:    [] Virtual_Member.Entry;
    
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
    
    for *level.entities  remap_entity_template_id_for_storage(it);
    defer for *level.entities  remap_entity_template_id_for_runtime(it);
    
    // shallow copy of level data, since we don't want to have to worry about cloning/freeing unnecessarily
    level_file: Level_Layout_File;
    level_file.base = level.base;
    
    // TODO: think about how we can remap directly into write so that we don't generate so much temporary data
    //       we should improve the data packer to be able to use fwrite/fread instead of always creating a binary blob
    level_file.tilemaps = NewArray(level.tilemaps.count, Tilemap_File);
    for *level_file.tilemaps {
        src := *level.tilemaps[it_index];
        
        it.formal_properties = src.formal_properties;
        it.data, it.size = trim_tilemap_data(src);
    }
    defer {
        for level_file.tilemaps {
            array_free(it.data);
        }
        array_free(level_file.tilemaps);
    }
    
    // entities require some manual remapping. we may do similarly for other things in the future
    {
        count := get_count_occupied(level.entities);
        level_file.entities = NewArray(count, Entity_File, initialized = false); 
        index := 0;
        for level.entities {
            level_file.entities[index].formal_properties = it.formal_properties;
            level_file.entities[index].common_properties = it.formal_common_properties;
            index += 1;
        }
    }
    defer array_free(level_file.entities);
    
    level_file.entity_groups = clone_to_view(level.entity_groups);
    defer array_free(level_file.entity_groups);
    
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
    
    array_reserve(*level.tilemaps, level_file.tilemaps.count);
    for level_file.tilemaps {
        dst := array_add(*level.tilemaps); 
        dst.* = .{ 
            formal_properties = it.formal_properties,
            min_index = .{ 0, 0 },
            max_index = it.size - .{ 1, 1 },
        };
        dst.data = array_copy(it.data);
    }
    
    // entities require some manual remapping. we may do similarly for other things in the future
    if level.entities.capacity < level_file.entities.count {
        log("Warning: unable to copy entities array from level file to runtime level struct!");
    } else {
        for level_file.entities {
            get_next_slot(*level.entities, true).* = .{ 
                formal_properties = it.formal_properties,
                formal_common_properties = it.common_properties,
            };
        }
    }
    
    if !clone_from_view(*level.entity_groups, level_file.entity_groups) {
        log("Warning: unable to copy entity groups array from level file to runtime level struct!");
    }
    
    for *level.entities {
        if it.template_id == 0 then it.template_id = it.template_index;
    }
    
    for *level.tilemaps  remap_tile_ids_for_runtime(it);
    for *level.entities  remap_entity_template_id_for_runtime(it);
    
    // fix invalid entity member values
    for *level.entities {
        prep_entity(it);
        it.script_variable_index = -1;
    }
    
    if level.tempo == 0 then level.tempo = 1;
    
    // NOTE: this does not affect generation currently, so this just ensures that all reported indices match reailty
    init_all_entity_handles(level);
    
    for *level.tilemaps {
        if it.color_mod.a == 0 then it.color_mod = .{ 1, 1, 1, 1 };
        it.script_variable_index = -1;
    }
    
    for *level.entity_groups {
        it.script_variable_index = -1;
    }
    
    return true;
}



Entity_File :: struct {
    using formal_properties:    Entity.Formal_Properties;
    using common_properties:    Entity.Common_Properties;
}

Tilemap_File :: struct {
    using formal_properties:    Tilemap.Formal_Properties;
}

