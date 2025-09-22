pi  := 3.14159;
tau := 2.0 * pi;

fireball_id := find_entity_template_index_by_name("Fireball");

{
    center := (plat1.root_offset + plat2.root_offset) / 2.0;
    
    platform_range := Vector2.{ 0.5, 0.5 };
    
    foreach (plat1, plat2) {
        cycle_time   := random_float(3, 5);
        cycle_offset := random_float(0, 1);
        cycle_lerp   := cycle_over(time, cycle_time) + cycle_offset;
        
        if random_bool()  cycle_lerp = -cycle_lerp;
        
        set_next_offset(it, circle(cycle_lerp, 0) * platform_range);
    }
    
    fireball_count        := random_int(2, 4);
    fireball_cycle_time   := random_float(4, 7);
    fireball_cycle_offset := random_float(0, 1);    
    fireball_cycle_lerp   := cycle_over(time, fireball_cycle_time) + fireball_cycle_offset;
    
    fireball_direction := random_bool();
    
    for 0..fireball_count-1 {
        cycle_offset := fireball_cycle_offset + it.(float)/fireball_count.(float);
        cycle_lerp   := fireball_cycle_lerp + cycle_offset;
        if fireball_direction  cycle_lerp = -cycle_lerp;
        
        p1 := plat1.offset_next;
        p2 := plat2.offset_next;
        
        fireball_position := ellipse(cycle_lerp, p1, p2, 1, 1, 1, 2, 0);
        immediate_fireball(fireball_id, fireball_position, .{1,1});
    }
}



{
    center := (plat3.root_offset + plat4.root_offset) / 2.0;
    
    platform_range := distance(plat3.root_offset, plat4.root_offset) / 2.0;
    
    cycle_time   := random_float(4, 7);
    cycle_offset := random_float(0, 1);
    cycle_lerp   := cycle_over(time, cycle_time) + cycle_offset;
    if random_bool()  cycle_lerp = -cycle_lerp;
    
    set_position(plat3, center + circle(cycle_lerp,     0) * platform_range);
    set_position(plat4, center + circle(cycle_lerp+0.5, 0) * platform_range);
    
    fireball_count        := random_int(2, 3);
    fireball_cycle_time   := random_float(5, 10);
    fireball_cycle_offset := random_float(0, 1);    
    fireball_cycle_lerp   := cycle_over(time, fireball_cycle_time) + fireball_cycle_offset;
    
    // fireball_direction := random_bool(); 
    
    for 0..fireball_count-1 {
        cycle_offset := fireball_cycle_offset + it.(float)/fireball_count.(float);
        cycle_lerp   := fireball_cycle_lerp + cycle_offset;
        // if fireball_direction  cycle_lerp = -cycle_lerp;
        
        p1 := plat3.offset_next;
        p2 := plat4.offset_next;
        
        fireball_position := ellipse(cycle_lerp, p1, p2, 0.7, 2, 1, 3, 0);
        immediate_fireball(fireball_id, fireball_position, .{1,1});
    }
}
