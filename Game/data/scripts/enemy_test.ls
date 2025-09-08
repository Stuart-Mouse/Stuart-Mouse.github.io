
pi  := 3.14159;
tau := 2 * pi;

cycle_time :: 6?;

cycle := fmod(time, cycle_time) / cycle_time;

platform_range :: Vector2.{ 2, 1 }?;
moving_1.offset_next = moving_1.root_offset;
moving_1.offset_next += .{ 0, cos(tau * 2 * cycle) } * platform_range;

moving_2.offset_next = moving_2.root_offset;
moving_2.offset_next += .{ 0, -cos(tau * 2 * cycle) } * platform_range;


enemy_cycle_time :: 3?;

cycle = fmod(time, enemy_cycle_time) / enemy_cycle_time;

foreach (enemy_1, enemy_2, enemy_3, enemy_4, enemy_5, enemy_6, enemy_7, enemy_8, enemy_9, enemy_10) {
    enemy_range :: Vector2.{ 1.5, 1.5 }?;
    
    cycle_offset := fmod(it_index.(float), 10) / 10;
    // cycle_offset := 0;
    
    it.position = it.init_position;
    it.position += tilemaps[it.attached_to_tilemap].offset - tilemaps[it.attached_to_tilemap].root_offset;
    it.position += .{ sin(tau * (cycle+cycle_offset)),  cos(tau * (cycle+cycle_offset)) } * enemy_range;
}

