
// DEBUG STUFF (up top so its all in one obvious place)
mouse_ray_start_position: Vec2f;
mouse_ray_end_position: Vec2f;
// END DEBUG STUFF


executable_path: string;

WINDOW_WIDTH  := 1920;
WINDOW_HEIGHT := 1080;

TILE_UNIT         := 32.0;
TILE_TEXTURE_SIZE :: 16;

TICKS_PER_FRAME    :: 1000.0 / 60.0;
FRAMES_PER_SECOND  := 60.0;
UPDATES_PER_FRAME  := 2.0;
UPDATES_PER_SECOND := 60.0;

camera_constants: struct {
    focus_distance:    float;
    movement_lerp:     float;
    focus_lerp:        float;
    focus_vel_scalar:  float;
}

Program_State: enum { GAME; EDITOR; } = .GAME;

default_level_path: string; // level to load when we init the game

load_global_config :: () -> bool {
    ok := LSD.load_and_parse_file("data/globals.gon", #code {
        LSD.add_data_binding_to_dom(*parser, FRAMES_PER_SECOND, "framerate");
        LSD.add_data_binding_to_dom(*parser, TILE_UNIT, "tile_render_unit");
        
        LSD.add_data_binding_to_dom(*parser, WINDOW_WIDTH,  "window_init_width");
        LSD.add_data_binding_to_dom(*parser, WINDOW_HEIGHT, "window_init_height");
        
        LSD.add_data_binding_to_dom(*parser, camera_constants, "camera_constants");
        
        LSD.add_data_binding_to_dom(*parser, Game.player_controllers, "player_controllers");
        LSD.add_data_binding_to_dom(*parser, editor_controller, "editor_controller");
        
        LSD.add_data_binding_to_dom(*parser, default_enemy_physics, "default_enemy_physics");
        
        LSD.add_data_binding_to_dom(*parser, default_level_path, "default_level_path");
    });
    if !ok  return false;
    
    UPDATES_PER_SECOND = FRAMES_PER_SECOND * UPDATES_PER_FRAME;
    
    camera_constants.focus_vel_scalar *= UPDATES_PER_SECOND;
    camera_constants.focus_lerp = pow(camera_constants.focus_lerp, 24.0 / UPDATES_PER_SECOND); // TODO: just ignoring value in file for now?
    
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





