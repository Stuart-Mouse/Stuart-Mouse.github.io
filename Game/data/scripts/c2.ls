
fireball_id := find_entity_template_index_by_name("Fireball");

for platform: members_of(platforms) {
    platform_range := Vector2.{ 0, 2 };
    platform_width := random_float(1, 3);
    
    platform.scale.x = platform_width;
    
    cycle_lerp := cycle_over_random(time, 3, 5, true, true);
    set_next_offset(platform, circle(cycle_lerp, 0) * platform_range);
    
    fireball_count      := platform_width.(int) + random_int(0, 1);
    fireball_cycle_lerp := cycle_over_random(time, 2, 4, true, true);
    
    // TODO: write iteration macro to distribute elements across a path
    for 0..fireball_count-1 {
        cycle_offset := it.(float)/fireball_count.(float);
        cycle_lerp   := fireball_cycle_lerp + cycle_offset;
        
        fireball_position := platform.offset_next + circle(cycle_lerp, 0) * .{ platform_width/2 + 1, 0.75 };
        immediate_fireball(fireball_id, fireball_position, .{1,1});
    }
}
