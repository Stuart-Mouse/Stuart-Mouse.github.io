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


