
// init: {
//     platform_count := random_int(3, 6);
//     for 1..platform_count {
//         entity := make_entity(template_id);
//         add_to_group(entity, "wheel_platforms");
//     }
// }



// {
//     // TODO: create marker entity to use which does not inherently move
//     center := wheel.position;
    
//     wheel_radius :: 5.0?
    
//     // TODO: need to be able to do immediate-mode platform entities, or else just set up the entities in the init block
//     cycle_offset := random_float(0, 1);
    
//     platforms := entity_group("wheel_platforms");
//     for platform: platforms {
//         it_cycle_offset := (offset + it_index.(float)/platforms.count.(float)) * TAU;
//         unit := unit_vector_given_angle(it_cycle_offset);
        
//         offset := center + unit * wheel_radius;
//         set_next_offset(platform, offset);
//     }
    
    
// }

chain_palette := palette_id("wood");
fireball_id := find_entity_template_index_by_name("Fireball");

for members_of(orbiters) {
    it->range :: Vector2.{ 1.5, 1.5 };
    if ui_append_to(it) {
        ui_range_handle(ui_id("range"), it->range.(Vector2), true);
        ui_pop();
    }
    
    cycle_time := 15.0;
    if !is_member_of(it, wheel_center) {
        cycle_time = random_float(5, 10);
    }
    
    cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
    
    set_next_offset(it, ellipse(cycle_lerp, random_int(1, 2).(float), random_int(1, 2).(float), random_float(0, 1)) * it->range.(Vector2));
    
    // set_next_offset(it, .{0,0});
}

should_do_fire_ring := false;
should_do_fire_bar := false;

for members_of(wheel_center) {
    center := it.position;
    platform_width := random_float(1, 2.5);
    
    _orbital_count := 5.0 / platform_width;
    orbital_count := _orbital_count.(int);
    
    radius := random_float(2, 4);
    
    cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    
    for 0..orbital_count-1 {
        id := random_get();
        it_lerp := cycle_lerp + (it.(float) / orbital_count.(float));
        platform_position := center + circle(it_lerp, 0) * radius;
        
        immediate_platform(id, platform_position, .{ platform_width, 1 });
        do_movement_visualizer_chain(center, platform_position, chain_palette, .{0.25,0.25,0.25,1});
        
        if should_do_fire_ring {
            fireball_cycle_lerp := cycle_over_random(time, 2, 4, true, true);
            ring_size := Vector2.{ platform_width/2 + 1, 0.75 };
            do_fire_ring(platform_position, fireball_cycle_lerp, ring_size, TAU, 1);
        }
    }
    
    if should_do_fire_bar {
        cycle_lerp := cycle_over_random(time, 2, 4, true, true);
        fire_bar_radius := radius + 2.0;
        spread := 2.0;
        count := fire_bar_radius / spread;
        do_fire_bar(center, cycle_lerp, count.(int), spread, 1.0, spread);
    }
}


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