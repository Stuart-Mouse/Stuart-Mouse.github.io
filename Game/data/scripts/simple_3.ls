// init: {
//     for members_of(orbiters) {
//         if random_int(0,9) == 0 {
//             add_to_group(it, wild);
//             it.palette = palette_id("enemy_hard");
//         }
//     }
// }

update: {
    for tilemap: members_of(posts) {
        tilemap->endpoint       :: Vector2.{ 0, -3 };
        tilemap->cycle_offset   :: 0.0;
        tilemap->cycle_time_min :: 3.0;
        tilemap->cycle_time_max :: 6.0;
        
        if ui_append_to(tilemap) {
            ui_offset_handle(ui_id("offset"), tilemap->endpoint.(Vector2), true);
            ui_pop();
        }
        
        cycle_lerp := cycle_over_random(time, tilemap->cycle_time_min.(float), tilemap->cycle_time_max.(float), false, false);
        cycle_lerp  = fmod(cycle_lerp + tilemap->cycle_offset.(float), 1);
        cycle_lerp  = sin(cycle_lerp * TAU) / 2.0 + 0.5;
        
        set_next_offset(tilemap, cycle_lerp * tilemap->endpoint.(Vector2));
    }
    
    // for members_of(orbiters) {
    //     it->range :: Vector2.{ 1.5, 1.5 };
    //     if ui_append_to(it) {
    //         ui_range_handle(ui_id("range"), it->range.(Vector2), true);
    //         ui_pop();
    //     }
        
    //     cycle_time := random_float(2, 4);
    //     cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
        
    //     if is_member_of(it, wild) {
    //         sin_cycle := cycle_over_random(time, cycle_time, cycle_time.(float) * 2.0, true, true);
    //         cycle_lerp = cycle_lerp + sin(sin_cycle * TAU) * random_float(0.1, 0.5);
    //     }
        
    //     set_next_offset(it, circle(cycle_lerp, 0) * it->range.(Vector2));
    // }
}