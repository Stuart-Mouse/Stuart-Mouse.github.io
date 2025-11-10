init: {
    for entity_group("pendulums") {
        it.movement_visualizer.kind = .CHAIN;
        it.movement_visualizer.palette = it.palette;
        it.movement_visualizer.color = .{0.5,0.5,0.5,1};
        
        it.movement_visualizer.anchor_point.kind = .STUD;
        it.movement_visualizer.anchor_point.palette = it.palette;
        it.movement_visualizer.anchor_point.color = .{0.5,0.5,0.5,1};
    }
    for entity_group("fireballs") {
        it.movement_visualizer.kind = .CHAIN;
        it.movement_visualizer.palette = it.palette;
        it.movement_visualizer.color = .{0.25,0.25,0.25,1};
        
        it.movement_visualizer.anchor_point.kind = .STUD;
        it.movement_visualizer.anchor_point.palette = it.palette;
        it.movement_visualizer.anchor_point.color = .{0.25,0.25,0.25,1};
    }
}

for platform: entity_group("pendulums") {
    pendulum_distance := 5.0;
    pendulum_angle    := degrees_to_radians(random_float(5, 8));
    
    pendulum_cycle_time := TAU * sqrt(pendulum_distance/30.0);
    cycle_lerp := cycle_over_random(time, pendulum_cycle_time, pendulum_cycle_time, true, true);
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(platform, offset);
    
    platform_width := random_float(2, 3);
    platform.scale.x = platform_width;
}

// TODO: need better way of expressing relation between fireball and pendulum platform
//       could do the fireball in immediate mode if we had movement visualizers for immediate-mode entities
for entity_group("fireballs") {
    pendulum_distance    := 4.0;
    pendulum_angle       := degrees_to_radians(random_float(3, 10));
    
    cycle_time := TAU * sqrt(pendulum_distance/10.0);
    cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(it, offset);
}