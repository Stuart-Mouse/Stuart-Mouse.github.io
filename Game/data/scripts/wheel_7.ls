chain_palette :: palette_id("wood");
fireball_id :: find_entity_template_index_by_name("Fireball");
large_fireball_id :: find_entity_template_index_by_name("Large Fireball");

update: {
    for platform: members_of(wheel_type_2) {
        center := platform.root_offset;
        
        platform->radius            :: 2.0;
        platform->cycle_time        :: 5.0;
        platform->cycle_offset      :: 0.0;
        platform->direction         :: -1;
        
        platform->do_fireball       :: true;
        
        
        cycle_lerp := fmod(cycle_over(time, platform->cycle_time) + platform->cycle_offset.(float), 1);
        
        // 0 = clockwise only, 1 = counter-clockwise only, -1 = randomize
        direction := platform->direction.(int);
        
        do_reverse := ifx (direction == -1) then random_bool() else direction.(bool);
        if do_reverse then cycle_lerp = 1.0 - cycle_lerp;
        
        platform_offset := circle(cycle_lerp, 0) * platform->radius.(float);
        set_next_offset(platform, platform_offset);
        do_movement_visualizer_chain(center, center + platform_offset, chain_palette, .{0.25,0.25,0.25,1});
        
        if platform->do_fireball.(bool) {
            immediate_fireball(large_fireball_id, center - platform_offset, .{ 1, 1 });
            do_movement_visualizer_chain(center, center - platform_offset, chain_palette, .{0.25,0.25,0.25,1});
        }
    }
    
}