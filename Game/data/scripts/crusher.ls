
for tilemap: members_of(crushers) {
    tilemap->cycle_time :: 2.0;
    lerp := cycle_over(time, tilemap->cycle_time);
    
    // not doing this for now, because it means that player can jsut competely ignore the main idea
    // if it_index == 1 {
    //     if random_bool()  lerp = cycle_over(lerp + 0.5, 1.0);
    // }
    
    // TODO: add virtual members for crusher lerp parameters as well
    lerp  = crusher_lerp(lerp, 0.425, 0.425);
    
    tilemap->endpoint :: Vector2.{ 0, -3 };
    if ui_append_to(tilemap) {
        ui_offset_handle(ui_id("offset"), tilemap->endpoint.(Vector2), true);
        ui_pop();
    }
    
    set_next_offset(tilemap, tilemap->endpoint.(Vector2) * lerp);
}
