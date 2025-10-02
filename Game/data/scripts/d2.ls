init: {
    pendulums := entity_group("pendulums");
    for pendulums {
        it.movement_visualizer.type = .DOTTED_LINE;
    }
    
    fireballs := entity_group("fireballs");
    for fireballs {
        it.movement_visualizer.type = .DOTTED_LINE;
    }
}
fireball_id := find_entity_template_index_by_name("Fireball");

pendulums := entity_group("pendulums");
for pendulums {
    pendulum_distance     := random_float(5, 8);
    pendulum_cycle_time   := pendulum_distance * 0.75 - random_float(0.25, 1);
    pendulum_cycle_offset := random_float(0, 1);
    pendulum_angle        := degrees_to_radians(random_float(3, 5));
    
    cycle_lerp := cycle_over(time, pendulum_cycle_time) + pendulum_cycle_offset;
    
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(it, offset);
    
    platform_width := random_float(1, 2.5);
    it.scale.x = platform_width;
    
    
    platform_position := it.position;
    
    fireball_count        := platform_width.(int);// + random_int(0, 1);
    fireball_cycle_time   := random_float(2, 4);
    fireball_cycle_offset := random_float(0, 1);
    fireball_cycle_lerp   := cycle_over(time, fireball_cycle_time) + fireball_cycle_offset;
    
    fireball_direction := random_bool();
    
    for 0..fireball_count-1 {
        cycle_offset := fireball_cycle_offset + it.(float)/fireball_count.(float);
        cycle_lerp   := fireball_cycle_lerp + cycle_offset;
        if fireball_direction  cycle_lerp = -cycle_lerp;
        
        fireball_position := platform_position + circle(cycle_lerp, 0) * .{ platform_width/2 + 1, 0.75 };
        immediate_fireball(fireball_id, fireball_position, .{1,1});
    }
}



fireballs := entity_group("fireballs");
for fireballs {
    pendulum_distance := 5.8;
    pendulum_angle    := degrees_to_radians(random_float(2.5, 10));
    cycle_lerp        := cycle_over_random(time, 2, 4, true, true);
    
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(it, offset);
}


// bottom platform
{
    cycle_lerp := cycle_over_random(time, 10, 15, false, false) + 0.25;
    offset := circle(cycle_lerp, 0) * .{ 20-4-platform.scale.x/2, 0 };
    set_next_offset(platform, offset);
}
