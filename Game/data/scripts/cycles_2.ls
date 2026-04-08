fireball_id :: find_entity_template_index_by_name("Fireball");
large_fireball_id :: find_entity_template_index_by_name("Large Fireball");

screen_x :: 40.0;
screen_y :: 28.0;

platform_y               :: 23.0;
platform_width           :: 1.5;
platform_count           :: 5;
platform_wiggle_distance :: 1.0;

fireball_y_offset        :: -1.0;
fireball_count           :: random_int(6, 8);
fireball_wiggle_distance :: 1.0;

update: {
    // generate platforms
    x_pos_1 := 12.0;
    x_pos_2 := 28.0;
    for x_pos: x_pos_1, x_pos_2 {
        wave_height       := random_float(0.5, 1.0);
        wave_frequency    := random_int(3, 4).(float);
        wave_cycle_offset := cycle_over_random(time, 8, 16, true, true);
        
        platform_cycle_offset := cycle_over_random(time, 8, 10, true, false);
        for 0..platform_count-1 {
            id := random_get();
            
            it_wiggle := sin(cycle_over_random(time, 2, 8, true, true) * TAU) * platform_wiggle_distance;
            
            it_cycle_offset := platform_cycle_offset 
                             + (it.(float) / platform_count.(float))
                             + (it_wiggle / screen_y);
            
            y_cycle_lerp := fmod(it_cycle_offset, 1);
            
            x_cycle_lerp := fmod(wave_cycle_offset + it_cycle_offset, 1);
            it_wave := sin(x_cycle_lerp * wave_frequency * TAU) * wave_height;
            
            platform_position := Vector2.{ x_pos + it_wave, y_cycle_lerp * screen_y };
            
            immediate_platform(id, platform_position, .{ platform_width, 1 });
        }
    }
    
    // generate fireballs
    {
        x_pos := 20.0;
        
        wave_height       := random_float(0.5, 1.5);
        wave_frequency    := random_int(3, 4).(float);
        wave_cycle_offset := cycle_over_random(time, 8, 16, true, true);
        
        fireball_cycle_offset := cycle_over_random(time, 4, 7, true, true);
        for 0..fireball_count-1 {
            it_wiggle := sin(cycle_over_random(time, 2, 8, true, true) * TAU) * fireball_wiggle_distance;
            
            it_cycle_offset := fireball_cycle_offset 
                             + (it.(float) / fireball_count.(float))
                             + (it_wiggle / screen_y);
            
            y_cycle_lerp := fmod(it_cycle_offset, 1);
            
            x_cycle_lerp := fmod(wave_cycle_offset + it_cycle_offset, 1);
            it_wave := sin(x_cycle_lerp * wave_frequency * TAU) * wave_height;
            
            fireball_position := Vector2.{ x_pos + it_wave, y_cycle_lerp * screen_y };
            
            id := ifx random_int(0, 9) == 0 then large_fireball_id else fireball_id;
            immediate_fireball(id, fireball_position, .{ 1, 1 });
        }
    }
}