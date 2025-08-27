
Worldmap :: struct {
    levels:       [..] Level_Info;
    active_level: int;
    active_area:  int;
}

Level_Info :: struct {
    name:         string;
    areas:        [..] Area;
    
    Area :: struct {
        name:         string;
        layout:       string;
        // music:        string;
        // script:       string;
    }
}

get_active_level_and_area :: () -> (bool, *Level_Info, *Level_Info.Area) {
    using Game.worldmap;
    
    if !is_valid_index(levels, active_level)  return false, null, null;
    level := *levels[active_level];
    
    if !is_valid_index(level.areas, active_area)  return false, null, null;
    area  := *level.areas[active_area];
    
    return true, level, area;
}

unload_worldmap :: () {
    using Game.worldmap;
    
    for *level: levels {
        for *area: level.areas {
            free(area.name);
            free(area.layout);
            // if area.layout  deinit_level(area.layout);
        }
        array_free(level.areas);
    }
    array_free(levels);
    
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
*/