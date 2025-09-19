init: {
    
    
}

pi  := 3.14159;
tau := 2 * pi;

fireball_id := find_entity_template_index_by_name("Fireball");

circle_group := entity_group("platforms");
for circle_group {
    platform_range := Vector2.{ 0, 2 };
    platform_width := random_float(1, 3);
    
    it.scale.x = platform_width;
    
    cycle_time   := random_float(3, 5);
    cycle_offset := random_float(0, 1);
    cycle_lerp   := cycle_over(time, cycle_time) + cycle_offset;
    
    if random_bool()  cycle_lerp = -cycle_lerp;
    
    set_next_offset(it, circle(cycle_lerp, 0) * platform_range);
    
    platform_position := it.position;
    
    fireball_count        := platform_width.(int) + random_int(0, 1);
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

