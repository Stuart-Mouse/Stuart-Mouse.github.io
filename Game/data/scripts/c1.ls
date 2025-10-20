init: {
    // for jeff, steve, roger {
    //     it.palette = 3;
    // }
    for entity_group("orbiters") {
        it->cycle_time = random_float(1.5, 4);
        // it->cycle_direction = 1;
        // if random_bool() it->cycle_direction = -1;
        it->cycle_offset = random_float(0, 1);
    }
}

{
    platform_range :: Vector2.{ 0, 1 }?;
    
    cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    
    set_next_offset(moving_1, circle(cycle_lerp, 0) * platform_range);
    set_next_offset(moving_2, .{ 0, -moving_1.offset_next.y });
}

fireball_id := find_entity_template_index_by_name("Fireball");

enemy_range :: Vector2.{ 1.5, 1.5 }?;
input_vec2("enemy_range", enemy_range);

for entity_group("orbiters") {
    cycle_lerp := cycle_over(time + it->cycle_offset.(float), it->cycle_time);
    set_next_offset(it, circle(cycle_lerp, 0) * enemy_range);
}

for jeff, steve, roger {
    it.offset_next += circle(time, 0) * 0.5;
}
