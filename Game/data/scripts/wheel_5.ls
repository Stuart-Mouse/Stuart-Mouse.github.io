/*
    
*/


chain_palette := palette_id("wood");

fireball_id := find_entity_template_index_by_name("Fireball");

for platform: members_of(wheel) {
    center := platform.position;
    set_next_offset(platform, .{});
    platform.scale.x = 0.5;
    
    platform->platform_width    :: 1.5;
    platform->orbital_count     :: 5;
    platform->radius            :: 4.0;
    platform->cycle_time        :: 5.0;
    platform->direction         :: -1;
    
    cycle_lerp := cycle_over(time, platform->cycle_time);
    
    // 0 = clockwise only, 1 = counter-clockwise only, -1 = randomize
    direction := platform->direction.(int);
    
    // TODO: bool to int conversion seems broken.
    do_reverse := direction == 1;
    if direction == -1  do_reverse = random_bool();
    if do_reverse  cycle_lerp = 1.0 - cycle_lerp;
    
    for 0..platform->orbital_count.(int)-1 {
        id := random_get();
        it_lerp := cycle_lerp + (it.(float) / platform->orbital_count.(int).(float));
        platform_position := center + circle(it_lerp, 0) * platform->radius.(float);
        
        immediate_platform(id, platform_position, .{ platform->platform_width.(float), 1 });
        do_movement_visualizer_chain(center, platform_position, chain_palette, .{0.25,0.25,0.25,1});
    }
}


set_next_offset(right_gate, .{ 0, random_float(0, 3) });


