/*
    Ideas:
    
    with circle on circle:
        1. first and second circle radius sum to the same amount, but how that total radius is distributed changes
            with a vertical barrier of some sort, at what height do we need some hole in the wall in each case?
            how does varyind the direciton of spin affect things?
                the longer arm is going to be more important!
                perhaps the first arm should always be longer than the second
                    Then we can vary only the direction of spin of the smaller arm
                    or we determine whether to vary the each arm based on the difficulty level
            can we also make the design work with a horizontal barrier of some kind?
                will probably require multiple platforms, since we would have to determine when to drop through the hole from above
                    if we have multiple circles spread along x axis, one above barrier and one below, then perhaps we can drop from one wheel onto another
                    and if the wheels don't line up, we have to treadmill on the first before dropping through
*/

fireball_id := find_entity_template_index_by_name("Fireball");


for platform: members_of(wheel) {
    platform_width := 1.5;
    platform.scale.x = 1.5;
    
    subcycle := 5;
    
    radius := 7.5;
    cycle_lerp := 1.0 - cycle_over(time + 5.0, 4.0 * subcycle.(float));
    
    set_next_offset(platform, circle(cycle_lerp, 0) * radius);
    do_movement_visualizer_chain(get_attachment_offset(platform), platform.offset, platform.palette, .{0.25,0.25,0.25,1});
    
    orbital_count := 1;
    // _orbital_count := 5.0 / platform_width;
    // orbital_count := _orbital_count.(int);
    
    subcycle_offset := 0.5;
    cycle_lerp = fmod(cycle_lerp * subcycle.(float) + subcycle_offset, 1.0);
    
    radius = 3.5;
    for 0..orbital_count-1 {
        id := random_get();
        it_lerp := cycle_lerp + (it.(float) / orbital_count.(float));
        orbital_position := platform.offset + circle(it_lerp, 0) * radius;
        
        immediate_platform(id, orbital_position, .{ platform_width, 1 });
        
        do_movement_visualizer_chain(platform.offset, orbital_position, platform.palette, .{0.25,0.25,0.25,1});
    }
}



for members_of(orbiters) {
    it->range :: Vector2.{ 1.5, 1.5 };
    if ui_append_to(it) {
        ui_range_handle(ui_id("range"), it->range.(Vector2), true);
        ui_pop();
    }
    
    cycle_time := random_float(5, 10);
    cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
    
    set_next_offset(it, ellipse(cycle_lerp, random_int(1, 3).(float), random_int(1, 3).(float), random_float(0, 1)) * it->range.(Vector2));
    // set_next_offset(it, .{0,0});
}