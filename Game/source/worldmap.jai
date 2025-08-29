
// level info is separate from map.csv data
// so when we want to move form one level to another, we have to locate the current level on the map and then step in whatever direction we move
Worldmap :: struct {
    level_info:     [..] Level_Info;
    map_data:       Map_Data;
    
    INVALID_MAP_INDEX :: Vec2i.{ -1, -1 };
}

Map_Data :: struct {
    data: [#run size.x * size.y] Static_String(16);
    size :: Vec2i.{ 64, 64 };
}

get_level_info :: (worldmap: *Worldmap, index: int) -> *Level_Info {
    if index < 0 || index > worldmap.level_info.count {
        return null;
    }
    return *worldmap.level_info[index];
}

get_level_info :: (worldmap: *Worldmap, name: string) -> *Level_Info {
    for *worldmap.level_info {
        if it.name == name  return it;
    }
    return null;
}

get_level_info_index :: (worldmap: Worldmap, name: string) -> int {
    for worldmap.level_info {
        if it.name == name  return it_index;
    }
    return -1;
}

get_level_name_from_map_index :: (worldmap: Worldmap, index: Vec2i) -> string {
    if index.x < 0 || index.x >= worldmap.map_data.size.x 
    || index.y < 0 || index.y >= worldmap.map_data.size.y {
        return "";
    }
    index_1d := index.y * worldmap.map_data.size.x + index.x;
    return to_string(*worldmap.map_data.data[index_1d]);
}

get_map_index_from_level_name :: (worldmap: Worldmap, name: string) -> Vec2i {
    for *worldmap.map_data.data {
        if to_string(it) == name {
            return .{ xx (it_index % worldmap.map_data.size.x), xx (it_index / worldmap.map_data.size.x) };
        }
    }
    return Worldmap.INVALID_MAP_INDEX;
}

unload_worldmap :: () {
    using Game.worldmap;
    
    for *level: level_info {
        free(level.name);
    }
    array_free(level_info);
    
    Game.worldmap = .{};
}

load_worldmap :: (file_path: string) -> bool {
    unload_worldmap();
    
    ok := LSD.load_and_parse_file(file_path, #code {
        LSD.add_data_binding_to_dom(*parser, Game.worldmap, "worldmap");
    });
    if !ok  return false;
    
    return true;
}

/*
    In order to simplify things for the time being, I will be reworking the worldmap to function in terms of a csv-like grid of screens
    
    This will currently limit levels to a single non-scrolling screen, which I would like to step away from in the future, 
    but for the time being it will allow me to actually work on content if the technical side of connecting those levels is simplified.
    
    It will also allow me to move between levels in game and in the editor much faster
    
    later, maybe we have some kind of linker entity that we can use to connect levels in a looser sort of way
        probably better if this is not an entity type, but just a simple rect + warp locator
        
    
*/


parse_csv :: (
    csv:        string, 
    data:       *$T, 
    on_comma:   (row: int, column: int, value: string, data: *T) -> bool, 
    on_newline: (row: int, column: int, value: string, data: *T) -> bool
) -> bool {
    row, column: int;
    value := string.{ 0, csv.data };
    for *csv {
        if it.* == {
          case #char ",";
            if !on_comma(row, column, value, data)  return false;;
            value = string.{ 0, it+1 };
            column += 1;
            
          case #char "\n";
            if !on_newline(row, column, value, data)  return false;;
            value = string.{ 0, it+1 };
            row += 1;
            column = 0;
            
          case;
            value.count += 1;
        }
    }
    return true;
}

// save_map_csv :: (worldmap: *Worldmap, csv_file_path: string) {
//     assert(worldmap.size.x * worldmap.size.y == worldmap.map_data.count);
    
//     builder: String_Builder;
//     for worldmap.map_size.y {
//         for worldmap.map_size.x {
//             append(*builder, "");
//             append(*builder, ",");
//         }
//         append(*builder, "\n");
//     }
//     return builder_to_string(*builder);
// }

// log_csv :: (using csv: *CSV) {
//     assert(size.x * size.y == xx data.count);
    
//     builder: String_Builder;
//     for 0..size.y-1 {
//         for 0..size.x-1 {
//             append(*builder, "");
//             append(*builder, ",");
//         }
//         append(*builder, "\n");
//     }
//     log(builder_to_string(*builder));
// }