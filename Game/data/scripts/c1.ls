init: {
    for members_of(orbiters) {
        if random_int(0,19) == 0 {
            add_to_group(it, wild);
            it.palette = palette_id("enemy_hard");
        }
    }
}

{
    platform_range :: Vector2.{ 0, 1 }?;
    
    cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    
    set_next_offset(moving_1, circle(cycle_lerp, 0) * platform_range);
    set_next_offset(moving_2, .{ 0, -moving_1.offset_next.y });
}

enemy_range :: Vector2.{ 1.5, 1.5 }?;
input_vec2("enemy_range", enemy_range);

// TODO: The following should work, but it doesn't. Probably not evaluating the malleable literal properly...
// enemy_range := input_vec2("enemy_range", Vector2.{ 1.5, 1.5 }?);

for members_of(orbiters) {
    cycle_time := random_float(2, 4);
    cycle_lerp := cycle_over_random(time, 1.5, 4, true, true);
    
    if is_member_of(it, wild) {
        sin_cycle := cycle_over_random(time, cycle_time, cycle_time.(float) * 2.0, true, true);
        cycle_lerp = cycle_lerp + sin(sin_cycle * TAU) * random_float(0.1, 0.5);
    }
    
    set_next_offset(it, circle(cycle_lerp, 0) * enemy_range);
}
