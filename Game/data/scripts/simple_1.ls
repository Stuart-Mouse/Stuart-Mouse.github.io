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

// enemy_range :: Vector2.{ 1.5, 1.5 }?;
// input_vec2("enemy_range", enemy_range);

for members_of(orbiters) {
    it->range :: Vector2.{ 1.5, 1.5 };
    if ui_append_to(it) {
        id := ui_id("range");
        ok := ui_range_handle(id, it->range.(Vector2), true);
        ui_pop();
    }
    
    cycle_lerp := cycle_over_random(time, 1.5, 4, true, true);
    set_next_offset(it, circle(cycle_lerp, 0) * it->range.(Vector2));
}

for members_of(wild) {
    it.offset_next += circle(time, 0) * 0.5;
}
