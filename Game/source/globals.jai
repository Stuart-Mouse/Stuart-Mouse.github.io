
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

camera_constants: struct {
    focus_distance:    float;
    movement_lerp:     float;
    focus_lerp:        float;
    focus_vel_scalar:  float;
}

Program_State: enum { GAME; EDITOR; } = .GAME;

default_level_path: string; // level to load when we init the game

load_global_config :: () -> bool {
    ok := LSD.load_and_parse_file("data/globals.lsd", #code {
        LSD.add_data_binding_to_dom(*parser, frames_per_second, "framerate");
        LSD.add_data_binding_to_dom(*parser, tile_render_unit, "tile_render_unit");
        
        LSD.add_data_binding_to_dom(*parser, window_width,  "window_init_width");
        LSD.add_data_binding_to_dom(*parser, window_height, "window_init_height");
        
        LSD.add_data_binding_to_dom(*parser, camera_constants, "camera_constants");
        
        LSD.add_data_binding_to_dom(*parser, Game.player_controllers, "player_controllers");
        LSD.add_data_binding_to_dom(*parser, editor_controller, "editor_controller");
        
        LSD.add_data_binding_to_dom(*parser, default_enemy_physics, "default_enemy_physics");
        
        LSD.add_data_binding_to_dom(*parser, default_level_path, "default_level_path");
    });
    if !ok  return false;
    
    updates_per_second = frames_per_second * updates_per_frame;
    
    camera_constants.focus_vel_scalar *= updates_per_second;
    camera_constants.focus_lerp = pow(camera_constants.focus_lerp, 24.0 / updates_per_second); // TODO: just ignoring value in file for now?
    
    {
        using default_enemy_physics;
        
        walk\_speed              = units_per_second(walk\_speed);
        
        walk\_accel              = acceleration_for_velocity_over_time(walk\_speed, walk\_accel);
        
        ground_friction          = compute_friction(ground_friction);
        stop\ _friction          = compute_friction(stop\ _friction);
        air\  _friction          = compute_friction(air\  _friction);
        
        max_air\_speed           = units_per_second(max_air\_speed);
        max_fall_speed           = units_per_second(max_fall_speed);
        
        gravity             = units_per_second_squared(gravity);
    }
    
    return true;
}





