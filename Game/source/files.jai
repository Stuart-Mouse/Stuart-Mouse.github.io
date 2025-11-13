

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
    
    // shallow copy of level data, since we don't want to have to worry about cloning/freeing unnecessarily
    level_file: Level_Layout_File;
    level_file.base = level.base;
    
    // TODO: think about how we can remap directly into write so that we don't generate so much temporary data
    //       we should improve the data packer to be able to use fwrite/fread instead of always creating a binary blob
    level_file.tilemaps = NewArray(level.tilemaps.count, Tilemap_File);
    for *level_file.tilemaps {
        it.* = tilemap_to_file(*level.tilemaps[it_index]);
    }
    defer {
        for level_file.tilemaps {
            array_free(it.data);
        }
        array_free(level_file.tilemaps);
    }
    
    level_file.entities = map_to_view(level.entities, entity_to_file);
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
    for *level_file.tilemaps {
        array_add(*level.tilemaps, tilemap_from_file(it));
    }
    
    if !map_from_view(*level.entities, level_file.entities, entity_from_file) {
        log("Warning: unable to copy entities array from level file to runtime level struct!");
    }
    
    if !clone_from_view(*level.entity_groups, level_file.entity_groups) {
        log("Warning: unable to copy entity groups array from level file to runtime level struct!");
    }
    
    for *level.entities {
        if it.template_id == 0 then it.template_id = it.template_index;
    }
    
    // fix invalid entity member values
    for *level.entities {
        it.kind = .ENTITY;  // TODO: remove after all levels are updated
        it.script_variable_index = -1;
        if it.uuid == 0 then it.uuid = get_actor_uuid();
        prep_entity(it);
    }
    
    if level.tempo == 0 then level.tempo = 1;
    
    for *level.tilemaps {
        it.kind = .TILEMAP; // TODO: remove after all levels are updated
        if it.color_mod.a == 0 then it.color_mod = .{ 1, 1, 1, 1 };
        it.script_variable_index = -1;
    }
    
    for *level.entity_groups {
        it.kind = .ENTITY_GROUP;    // TODO: remove after all levels are updated
        if it.uuid == 0 then it.uuid = get_actor_uuid();
        it.name = it.id;
        it.script_variable_index = -1;
    }
    
    return true;
}



Actor_File :: struct {
    uuid: Actor.UUID;
    name: Actor.Name;
}

actor_to_file :: (actor: *Actor) -> Actor_File {
    return .{ uuid = actor.uuid, name = actor.name };
}

actor_from_file :: (file: *Actor_File) -> Actor {
    return .{ uuid = file.uuid, name = file.name };
}


Entity_File :: struct {
    using actor: Actor_File;
    using formal_properties:    Entity.Formal_Properties;
    using common_properties:    Entity.Common_Properties;
}

entity_to_file :: (entity: *Entity) -> Entity_File {
    file: Entity_File;
    file.actor = actor_to_file(*entity.actor);
    file.formal_properties = entity.formal_properties;
    file.common_properties = entity.formal_common_properties;
    file.template_id = entity_template_runtime_id_to_storage_id(file.template_id);
    return file;
};

entity_from_file :: (file: *Entity_File) -> Entity {
    entity: Entity;
    entity.actor = actor_from_file(*file.actor);
    entity.formal_properties        = file.formal_properties;
    entity.formal_common_properties = file.common_properties;
    entity.template_id = entity_template_storage_id_to_runtime_id(entity.template_id);
    return entity;
}


Tilemap_File :: struct {
    using actor: Actor_File;
    using formal_properties:    Tilemap.Formal_Properties;
}

tilemap_to_file :: (tilemap: *Tilemap) -> Tilemap_File {
    file: Tilemap_File;
    file.actor = actor_to_file(*tilemap.actor);
    file.formal_properties = tilemap.formal_properties;
    file.data, file.size = trim_tilemap_data(tilemap);
    remap_tile_ids_for_storage(file.data);
    return file;
}

tilemap_from_file :: (file: *Tilemap_File) -> Tilemap {
    tilemap: Tilemap;
    tilemap.actor = actor_from_file(*file.actor);
    tilemap.formal_properties = file.formal_properties;
    tilemap.min_index = .{ 0, 0 };
    tilemap.max_index = file.size - .{ 1, 1 };
    remap_tile_ids_for_runtime(tilemap.data);
    return tilemap;
}



Virtual_Member_Storage_File :: struct {
    entries: [..] Entry;
    Entry :: struct {
        uuid:   u64;    // only need uuid, can reconstruct full handle on load
        name:   string;
        value:  Any;
    }
}

vms_to_file :: (vms: *Virtual_Member_Storage) -> Virtual_Member_Storage_File {
    file: Virtual_Member_Storage_File;
    array_reserve(*file.entries, vms.entries.count);
    for vms.entries {
        dst := array_add(*file.entries);
        dst.uuid  = it.owner.uuid;
        dst.name  = it.name;
        dst.value = get_as_any(*it.tagged_union);
    }
    return file;
}

vms_from_file :: (file: *Virtual_Member_Storage_File) -> Virtual_Member_Storage {
    vms: Virtual_Member_Storage;
    array_reserve(*vms.entries, file.entries.count);
    for file.entries {
        dst := array_add(*vms.entries);
        dst.owner = get_actor_handle_from_uuid(it.uuid);
        dst.name  = it.name;
        set_any(*dst.tagged_union, it.value);
    }
    return vms;
}

save_virtual_members :: (level: *Level) {
    path := tprint("data/scripts/%.vms", path_strip_extension(to_string(*level.script_path)));
    
    using LSD;
    
    parser: Parser;
    init_parser(*parser, "");
    defer deinit_parser(*parser);
    
    file := vms_to_file(*level.script.virtual_member_storage);
    defer array_free(file.entries);
    
    LSD.register_type(*parser, "Color4", Color4);
    LSD.register_type(*parser, "Vec2f",  Vec2f);
    LSD.register_type(*parser, "Vec2i",  Vec2i);
    
    insert_data_node(*parser, parser.dom_root, "entries", file.entries);
    serialize_to_file(*parser, path);
}

load_virtual_members :: (level: *Level) {
    path := tprint("data/scripts/%.vms", path_strip_extension(to_string(*level.script_path)));
    
    file: Virtual_Member_Storage_File;
    defer array_free(file.entries);
    
    ok := LSD.load_and_parse_file(path, #code {
        // TODO: create helper proc to register all the common types I use for level scripts and other resources
        LSD.register_type(*parser, "Color4", Color4);
        LSD.register_type(*parser, "Vec2f",  Vec2f);
        LSD.register_type(*parser, "Vec2i",  Vec2i);
        
        LSD.add_data_binding_to_dom(*parser, file.entries, "entries");
    });
    // if !ok  return false;
    
    // TODO: we should actually try to declare, get and set value using the usual interface instead of just dumping all and reloading
    // level.script.virtual_member_storage = vms_from_file(*level.script.virtual_member_storage);
    array_reset_keeping_memory(*level.script.virtual_member_storage.entries);
    for file.entries {
        dst := array_add(*level.script.virtual_member_storage.entries);
        dst.owner = get_actor_handle_from_uuid(it.uuid);
        dst.name  = it.name;
        set_any(*dst.tagged_union, it.value);
    }
}
