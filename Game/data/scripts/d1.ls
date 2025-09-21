init: {
    
    
}

pi  := 3.14159;
tau := 2 * pi;

fireball_id := find_entity_template_index_by_name("Fireball");

// circle_group := entity_group("platforms");
// for 0..circle_group/2 {
    // plat1 := circle_group[it_index*2+0];
    // plat2 := circle_group[it_index*2+1];
    
    center := (plat1.root_offset + plat2.root_offset) / 2;
    
    platform_range := distance(plat1.root_offset, plat2.root_offset) / 2;
    
    // it.scale.x = platform_width;
    
    cycle_time   := 5;//random_float(3, 5);
    cycle_offset := 0;//random_float(0, 1);
    cycle_lerp   := cycle_over(time, cycle_time) + cycle_offset;
    
    // if random_bool()  cycle_lerp = -cycle_lerp;
    
    plat1.offset_next = center + circle(cycle_lerp,     0) * platform_range;
    plat2.offset_next = center + circle(cycle_lerp+0.5, 0) * platform_range;
    
    plat1.flags = plat1.flags | .POSITIONED_BY_SCRIPT;
    plat2.flags = plat2.flags | .POSITIONED_BY_SCRIPT;
    
    fireball_count        := random_int(1, 3);
    fireball_cycle_time   := random_float(5, 8);
    fireball_cycle_offset := random_float(0, 1);    
    fireball_cycle_lerp   := cycle_over(time, fireball_cycle_time) + fireball_cycle_offset;
    
    fireball_direction := random_bool();
    
    for 0..fireball_count-1 {
        cycle_offset := fireball_cycle_offset + it.(float)/fireball_count.(float);
        cycle_lerp   := fireball_cycle_lerp + cycle_offset;
        if fireball_direction  cycle_lerp = -cycle_lerp;
        
        p1 := plat1.offset_next;
        p2 := plat2.offset_next;
        
        fireball_position := ellipse2(cycle_lerp, p1, p2, 1, 2, 0);
        immediate_fireball(fireball_id, fireball_position, .{1,1});
    }
// }

