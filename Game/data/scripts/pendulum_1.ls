
// TODO: add some kind of for, syntax so we can do comma separated iterator with only one element
for ,tile_pendulum {
    pendulum_distance := 5.5;
    pendulum_angle    := degrees_to_radians(random_float(5, 8));
    
    pendulum_cycle_time := TAU * sqrt(pendulum_distance/30.0);
    cycle_lerp := cycle_over_random(time, pendulum_cycle_time, pendulum_cycle_time, true, true);
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(it, offset);
    
    do_movement_visualizer_chain(it.root_offset, it.offset, palette_id("brick_1"), .{0.25,0.25,0.25,1});
}

for ,spinner {
    cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    offset := circle(cycle_lerp, 0) * 3.0;
    set_next_offset(it, offset);
    do_movement_visualizer_chain(it.root_offset, it.offset, palette_id("wood"), .{0.25,0.25,0.25,1});
}

for platform: members_of(pendulums) {
    pendulum_distance := 5.0;
    pendulum_angle    := degrees_to_radians(random_float(5, 8));
    
    pendulum_cycle_time := TAU * sqrt(pendulum_distance/30.0);
    cycle_lerp := cycle_over_random(time, pendulum_cycle_time, pendulum_cycle_time, true, true);
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(platform, offset);
    
    platform_width := random_float(2, 3);
    platform.scale.x = platform_width;
    
    do_movement_visualizer_chain(get_attachment_offset(platform), platform.offset, platform.palette, .{0.25,0.25,0.25,1});
}

// TODO: need better way of expressing relation between fireball and pendulum platform
//       could do the fireball in immediate mode if we had movement visualizers for immediate-mode entities
for members_of(fireballs) {
    pendulum_distance    := 4.0;
    pendulum_angle       := degrees_to_radians(random_float(3, 10));
    
    cycle_time := TAU * sqrt(pendulum_distance/10.0);
    cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(it, offset);
    
    do_movement_visualizer_chain(get_attachment_offset(it), it.offset, it.palette, .{0.25,0.25,0.25,1});
}

for members_of(fire_ring) {
    cycle_lerp := cycle_over_random(time, 5, 8, true, true);
    radius := oscillate_between(3, 5, cycle_over_random(time, 3, 5, true, true));
    do_fire_ring(get_attachment_offset(it), cycle_lerp, radius * Vector2.{ 2, 1 }, TAU / 10.0, 1);
    // do_movement_visualizer_chain(get_attachment_offset(it), it.offset, it.palette, .{0.25,0.25,0.25,1});
}