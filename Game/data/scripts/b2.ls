init: {
    for members_of(walkers) {
        it.tempo = random_float(0.75, 1.5);
    }
    for members_of(floaters) {
        it.tempo = random_float(0.5, 1.25);
    }
}


platform_range :: Vector2.{ 0, 0.5 }?;

for moving_1, moving_2 {
    cycle_lerp := cycle_over_random(time, 5, 8, true, true);
    set_next_offset(it, circle(cycle_lerp, 0) * platform_range);
}


for members_of(floaters) {
    it->range :: Vector2.{ 1.5, 1.5 };
    if ui_append_to(it) {
        ui_range_handle(ui_id("range"), it->range.(Vector2), true);
        ui_pop();
    }
    
    cycle_time := random_float(5, 10);
    cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
    
    // ensuring the timescale values always sum to the same value means we always get something relatively balanced
    x_timescale := random_int(1, 3);
    y_timescale := 4 - x_timescale;
    set_next_offset(it, ellipse(cycle_lerp, x_timescale.(float), y_timescale.(float), random_float(0, 1)) * it->range.(Vector2));
    
    // set_next_offset(it, .{0,0});
}

