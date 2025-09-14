
pi  := 3.14159;
tau := 2 * pi;

// cycle_time := random_float(3, 7);
cycle_time := 7;
cycle := cycle_over(time, cycle_time);


platform_range :: Vector2.{ 0, 1 }?;

moving_1_cycle := cycle_over(time, random_float(5, 8)) + random_float(0, 1);
moving_1.offset_next = moving_1.root_offset;
moving_1.offset_next += .{ 0, 1 + cos(tau * 2 * moving_1_cycle) } * platform_range / 2;

moving_2_cycle := cycle_over(time, random_float(5, 8)) + random_float(0, 1);
moving_2.offset_next = moving_2.root_offset;
moving_2.offset_next += .{ 0, 1 - cos(tau * 2 * moving_2_cycle) } * platform_range / 2;
