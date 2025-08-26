window_width       := 1600;
window_height      := 1000;
frames_per_second  := 60.0;
updates_per_frame  := 1.0;
updates_per_second := 60.0;
ms_per_update      := (1000.0 / 60.0).(s64);

load_global_config :: () -> bool {
    ok := LSD.load_and_parse_file("data/config.lsd", #code {
        LSD.add_data_binding_to_dom(*parser, window_width,  "window_init_width");
        LSD.add_data_binding_to_dom(*parser, window_height, "window_init_height");
        
        LSD.add_data_binding_to_dom(*parser, frames_per_second, "frames_per_second");
        LSD.add_data_binding_to_dom(*parser, frames_per_second, "updates_per_frame");
    });
    if !ok  return false;
    
    updates_per_frame  = 1.0;
    updates_per_second = frames_per_second * updates_per_frame;
    ms_per_update      = (1000.0 / updates_per_second).(s64);
    
    return true;
}

