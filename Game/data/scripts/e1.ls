
platform_range :: Vector2.{ 0, 3 }?;

for left_platform, right_platform {
    cycle_lerp := cycle_over_random(time, 5, 8, true, true);
    set_next_offset(it, circle(cycle_lerp, 0) * platform_range);
}

