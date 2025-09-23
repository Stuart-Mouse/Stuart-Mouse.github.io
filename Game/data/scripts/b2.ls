
pi  := 3.14159;
tau := 2 * pi;

platform_range :: Vector2.{ 0, 0.5 }?;

foreach (moving_1, moving_2) {
    cycle_lerp := cycle_over_random(time, 5, 8, true, true);
    set_next_offset(it, circle(cycle_lerp, 0) * platform_range);
}
