fireball_id :: find_entity_template_index_by_name("Fireball");
large_fireball_id :: find_entity_template_index_by_name("Large Fireball");

screen_x :: 40.0;
screen_y :: 28.0;

update: {
    for marker: members_of(platform_stream) {
        marker->wave_height       :: random_float(0.5, 2);
        marker->wave_frequency    :: random_int(3, 4).(float);
        
        marker->platform_width           :: 1.5;
        marker->platform_count           :: 5;
        marker->platform_wiggle_distance :: 1.0;
        
        marker->cycle_time_min :: 8.0;
        marker->cycle_time_max :: 10.0;
        
        platform_y := marker.position.y;
        platform_count := marker->platform_count.(int);
        
        platform_cycle_offset := cycle_over_random(time, marker->cycle_time_min.(float), marker->cycle_time_max.(float), true, true);
        for 0..platform_count-1 {
            id := random_get();
            
            it_wiggle := sin(cycle_over_random(time, 2, 8, true, true) * TAU) * marker->platform_wiggle_distance.(float);
            
            it_cycle_offset := platform_cycle_offset 
                             + (it.(float) / platform_count.(float))
                             + (it_wiggle / screen_x);
            
            x_cycle_lerp := fmod(it_cycle_offset, 1);
            
            wave_cycle_offset := cycle_over_random(time, 8, 16, true, true);
            y_cycle_lerp := fmod(wave_cycle_offset + it_cycle_offset, 1);
            it_wave := sin(y_cycle_lerp * marker->wave_frequency.(float) * TAU) * marker->wave_height.(float);
            
            platform_position := Vector2.{ x_cycle_lerp * (screen_x+4) - 2, platform_y + it_wave };
            
            immediate_platform(id, platform_position, .{ marker->platform_width.(float), 1 });
        }
    }
    
    for marker: members_of(fireball_stream) {
        marker->wave_height       :: random_float(0.5, 2);
        marker->wave_frequency    :: random_int(3, 4).(float);
        
        marker->fireball_count           :: random_int(4, 7);
        marker->fireball_wiggle_distance :: 1.0;
        
        marker->cycle_time_min :: 4.0;
        marker->cycle_time_max :: 7.0;
        
        fireball_y     := marker.position.y;
        fireball_count := marker->fireball_count.(int);
        
        fireball_cycle_offset := cycle_over_random(time, marker->cycle_time_min.(float), marker->cycle_time_max.(float), true, true);
        for 0..fireball_count-1 {
            it_wiggle := sin(cycle_over_random(time, 2, 8, true, true) * TAU) * marker->fireball_wiggle_distance.(float);
            
            it_cycle_offset := fireball_cycle_offset 
                             + (it.(float) / fireball_count.(float))
                             + (it_wiggle / screen_x);
            
            x_cycle_lerp := fmod(it_cycle_offset, 1);
            
            wave_cycle_offset := cycle_over_random(time, 8, 16, true, true);
            y_cycle_lerp := fmod(wave_cycle_offset + it_cycle_offset, 1);
            it_wave := sin(y_cycle_lerp * marker->wave_frequency.(float) * TAU) * marker->wave_height.(float);
            
            fireball_position := Vector2.{ x_cycle_lerp * (screen_x+4) - 2, fireball_y + it_wave };
            
            // id := ifx random_int(0, 9) == 0 then large_fireball_id else fireball_id;
            immediate_fireball(fireball_id, fireball_position, .{ 1, 1 });
        }
    }
    
    
    for marker: members_of(mixed_stream) {
        marker->platform_wave_height       :: random_float(0.5, 2);
        marker->platform_wave_frequency    :: random_int(3, 4).(float);
        
        marker->platform_width           :: 1.5;
        marker->platform_count           :: 6;  // NOTE: this pattern requires an even number of platforms to work out because of how the fireballs cycle
        marker->platform_wiggle_distance :: 1.0;
        
        marker->platform_cycle_time_min :: 8.0;
        marker->platform_cycle_time_max :: 10.0;
        
        platform_y := marker.position.y;
        platform_count := marker->platform_count.(int);
        
        // platform_wave_cycle_offset := cycle_over_random(time, 8, 16, true, true);
        platform_wave_cycle_offset := 0.0;
        
        
        platform_cycle_offset := cycle_over_random(time, marker->platform_cycle_time_min.(float), marker->platform_cycle_time_max.(float), true, true);
        for 0..platform_count-1 {
            id := random_get();
            
            it_wiggle := 0.0;
            // it_wiggle := sin(cycle_over_random(time, 2, 8, true, true) * TAU) * marker->platform_wiggle_distance.(float);
            
            normalized_x := fmod(platform_cycle_offset + (it.(float) / platform_count.(float)) + (it_wiggle / screen_x), 1);
            
            y_cycle  := platform_wave_cycle_offset + normalized_x;
            y_offset := sin(y_cycle * marker->platform_wave_frequency.(float) * TAU) * marker->platform_wave_height.(float);
            
            platform_position := Vector2.{ normalized_x * (screen_x+4) - 2, platform_y + y_offset };
            
            immediate_platform(id, platform_position, .{ marker->platform_width.(float), 1 });
        }
        
        // this is added on top of the wave we inherit from the platform stream
        marker->fireball_wave_height     :: random_float(0.5, 2);
        marker->fireball_wave_frequency  :: random_int(3, 4).(float);
        
        marker->fireball_count           :: random_int(4, 7);
        marker->fireball_wiggle_distance :: 1.0;
        
        marker->fireball_cycle_time_min  :: 4.0;
        marker->fireball_cycle_time_max  :: 7.0;
        
        fireball_y     := marker.position.y;
        fireball_count := marker->fireball_count.(int);
        
        fireball_wave_cycle_offset := platform_cycle_offset;
        
        fireball_cycle_offset := cycle_over_random(time, marker->fireball_cycle_time_min.(float), marker->fireball_cycle_time_max.(float), true, true);
        for 0..fireball_count-1 {
            it_wiggle := sin(cycle_over_random(time, 2, 8, true, true) * TAU) * marker->fireball_wiggle_distance.(float);
            
            normalized_x := fmod(fireball_cycle_offset + (it.(float) / fireball_count.(float)) + (it_wiggle / screen_x), 1);
            
            // apply platform wave
            y_offset := sin(normalized_x * marker->platform_wave_frequency.(float) * TAU) * marker->platform_wave_height.(float);
            
            // apply fireball wave
            // wave needs to peak at locations of platforms
            // so we need to be able to assume that platforms are not offset on the x with some wiggle, but are at regular intervals
            scaled_x := (normalized_x - platform_cycle_offset) * platform_count.(float);
            y_offset += cos(scaled_x * PI) * marker->fireball_wave_height.(float) * ifx it & 1 then -1.0 else 1.0;
            
            fireball_position := Vector2.{ normalized_x * (screen_x+4) - 2, fireball_y + y_offset };
            
            immediate_fireball(fireball_id, fireball_position, .{ 1, 1 });
        }
    }
}

/*
    TODO: figure out how to nicely refer to parameters/virtual members of another marker so that fireballs can be parameterized on platforms
          or, just create a new group where fireballs and platforms are generated together so that we have state of both at the same time
          
    TODO: 
        parameterize fireball y position based on platform positions. fireballs should loop above/below the platforms reliably regardless of parameters of platform's movement
        fireball y should be totally independent of the rate of movement of fireballs along x axis so that we can adjust the speed of the fireballs without affecting the path
*/

