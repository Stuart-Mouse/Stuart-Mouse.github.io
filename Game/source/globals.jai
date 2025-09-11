
// DEBUG STUFF (up top so its all in one obvious place)
mouse_ray_start_position: Vec2f;
mouse_ray_end_position: Vec2f;
// END DEBUG STUFF


executable_path: string;

window_width  := 1920;
window_height := 1080;

tile_render_unit  := 32.0;
tile_texture_size :: 16;

frames_per_second  := 60.0;
updates_per_frame  := 2.0;
updates_per_second := 60.0;

microseconds_per_update: s64;

camera_constants: struct {
    focus_distance:    float;
    movement_lerp:     float;
    focus_lerp:        float;
    focus_vel_scalar:  float;
}

vsync_enabled := false;

toggle_vsync :: () {
    vsync_enabled = xx !vsync_enabled;
    #if OS == .WINDOWS {
        #import "GL";
        wglSwapIntervalEXT(xx vsync_enabled);
    }
}


Program_State: enum { GAME; EDITOR; } = .GAME;

default_level_path: string; // level to load when we init the game


load_global_config :: () -> bool {
    ok := LSD.load_and_parse_file("data/globals.lsd", #code {
        LSD.add_data_binding_to_dom(*parser, frames_per_second, "framerate");
        LSD.add_data_binding_to_dom(*parser, tile_render_unit, "tile_render_unit");
        LSD.add_data_binding_to_dom(*parser, vsync_enabled, "vsync_enabled");
        
        LSD.add_data_binding_to_dom(*parser, window_width,  "window_init_width");
        LSD.add_data_binding_to_dom(*parser, window_height, "window_init_height");
        
        LSD.add_data_binding_to_dom(*parser, camera_constants, "camera_constants");
        
        LSD.add_data_binding_to_dom(*parser, Game.player_controllers, "player_controllers");
        LSD.add_data_binding_to_dom(*parser, editor_controller, "editor_controller");
        
        LSD.add_data_binding_to_dom(*parser, default_level_path, "default_level_path");
        
        LSD.add_data_binding_to_dom(*parser, render_clear_color, "render_clear_color");
        
        LSD.add_data_binding_to_dom(*parser, textures_file_paths, "textures_file_paths");
    });
    if !ok  return false;
    
    if frames_per_second < 120 then updates_per_frame = max(updates_per_frame, 2);
    updates_per_second = frames_per_second * updates_per_frame;
    
    microseconds_per_update = (1000000.0 / updates_per_second.(float)).(s64);
    
    camera_constants.focus_vel_scalar *= updates_per_second;
    camera_constants.focus_lerp = pow(camera_constants.focus_lerp, 24.0 / updates_per_second); // TODO: just ignoring value in file for now?
    
    print_vars(vsync_enabled);

    return true;
}



level_file_paths: [..] string;

scan_for_level_files :: (path: string) {
    visit_files(path, true, *level_file_paths, (info: *File_Visit_Info, paths: *[..] string) {
        if path_extension(info.full_name) == "lvl" {
            array_add_if_unique(paths, copy_string(path_strip_extension(info.short_name)));
        }
    });
}
