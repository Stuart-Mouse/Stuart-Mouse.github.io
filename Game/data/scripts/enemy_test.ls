pi  := 3.14159;
tau := 2 * pi;

{
    platform_range :: Vector2.{ 0, 1 }?;
    
    cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    
    set_next_offset(moving_1, circle(cycle_lerp, 0) * platform_range);
    set_next_offset(moving_2, .{ 0, -moving_1.offset_next.y });
}

fireball_id := find_entity_template_index_by_name("Fireball");

enemy_range :: Vector2.{ 1.5, 1.5 }?;
input_vec2("enemy_range", enemy_range);

circle_group := entity_group("orbiters");
for circle_group {
    enemy_cycle_time := random_float(1.5, 4);
    
    cycle_lerp := cycle_over_random(time, 1.5, 4, true, true);
    if random_bool()  cycle_lerp = -cycle_lerp;
    
    set_next_offset(it, circle(cycle_lerp, 0) * enemy_range);
}
