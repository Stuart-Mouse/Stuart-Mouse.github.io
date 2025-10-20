// init: {
//     for jeff, steve, roger {
//         it.palette = 3;
//     }
// }

{
    platform_range :: Vector2.{ 0, 1 }?;
    
    cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    
    set_next_offset(moving_1, circle(cycle_lerp, 0) * Vector2.{0,1}.y);
    // set_next_offset(moving_1, circle(cycle_lerp, 0) * platform_range);
    set_next_offset(moving_2, .{ 0, -moving_1.offset_next.y });
}

fireball_id := find_entity_template_index_by_name("Fireball");

enemy_range :: Vector2.{ 1.5, 1.5 }?;
input_vec2("enemy_range", enemy_range);

circle_group := entity_group("orbiters");
for circle_group {
    cycle_lerp := cycle_over_random(time, 1.5, 4, true, true);
    set_next_offset(it, circle(cycle_lerp, 0) * enemy_range);
}

for jeff, steve, roger {
    my_global_any.(float) = 0.5;
    it.offset_next += circle(time, 0) * my_global_any.(float);
    // a := my_global_any.(int);
}
