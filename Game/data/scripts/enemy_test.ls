
pi  := 3.14159;
tau := 2 * pi;

// cycle_time :: 6?;
cycle_time := random_float(3, 7);

cycle := cycle_over(time, cycle_time);

platform_range :: Vector2.{ 2, 1 }?;
moving_1.offset_next = moving_1.root_offset;
moving_1.offset_next += .{ 0, cos(tau * 2 * cycle) } * platform_range;

moving_2.offset_next = moving_2.root_offset;
moving_2.offset_next += .{ 0, -cos(tau * 2 * cycle) } * platform_range;


// enemy_cycle_time :: 2?;
// enemy_cycle_time := random_float(1, 4);

circle_group := entity_group(0);
for circle_group {
    enemy_range :: Vector2.{ 1.5, 1.5 }?;
    
    enemy_cycle_time := random_float(1.5, 4);
    
    cycle_lerp := cycle_over(time, enemy_cycle_time);
    
    cycle_offset := random_float(0, 1);
    cycle_lerp += cycle_offset;
    
    if random_bool()  cycle_lerp = -cycle_lerp;
    
    it.position = default_position(it) + circle(cycle_lerp, 0) * enemy_range;
}

