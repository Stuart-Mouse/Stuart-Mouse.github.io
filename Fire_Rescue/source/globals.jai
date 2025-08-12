
executable_path: string;

window_width  := 1280;
window_height :=  720;

tile_render_unit  := 32.0;
tile_texture_unit :: 16;

ticks_per_frame    :: 1000.0 / 60.0;
frames_per_second  := 60.0;
updates_per_frame  := 1.0;
updates_per_second := 60.0;


load_global_config :: () -> bool {
    ok := LSD.load_and_parse_file("data/config.lsd", #code {
        LSD.add_data_binding_to_dom(*parser, frames_per_second, "frames_per_second");
        LSD.add_data_binding_to_dom(*parser, tile_render_unit, "tile_render_unit");
        
        LSD.add_data_binding_to_dom(*parser, window_width,  "window_init_width");
        LSD.add_data_binding_to_dom(*parser, window_height, "window_init_height");
    });
    if !ok  return false;
    
    updates_per_frame  = 1.0;
    updates_per_second = frames_per_second * updates_per_frame;
    
    return true;
}

