init: {
    for members_of(orbiters) {
        if random_int(0,9) == 0 {
            add_to_group(it, wild);
            it.palette = palette_id("enemy_hard");
        }
    }
}

for post_1, post_2, post_3, post_4 {
    platform_range :: Vector2.{ 0, 0.5 }?;
    cycle_lerp := cycle_over_random(time, 3, 8, true, true);
    set_next_offset(it, circle(cycle_lerp, 0) * platform_range);
}

for members_of(orbiters) {
    it->range :: Vector2.{ 1.5, 1.5 };
    if ui_append_to(it) {
        ui_range_handle(ui_id("range"), it->range.(Vector2), true);
        ui_pop();
    }
    
    it->cycle_time := random_float(2, 4);
    cycle_lerp := cycle_over_random(time, it->cycle_time, it->cycle_time, true, true);
    
    if is_member_of(it, wild) {
        sin_cycle := cycle_over_random(time, it->cycle_time, it->cycle_time.(float) * 2.0, true, true);
        cycle_lerp = cycle_lerp + sin(sin_cycle * TAU) * random_float(0.1, 0.5);
    }
    
    set_next_offset(it, circle(cycle_lerp, 0) * it->range.(Vector2));
}
