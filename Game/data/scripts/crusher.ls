
update: {
    for tilemap: members_of(crushers) {
        tilemap->cycle_time :: 2.0;
        tilemap->time_up    :: 0.4;
        tilemap->time_down  :: 0.4;
        
        lerp := cycle_over(time, tilemap->cycle_time);
        lerp = crusher_lerp(lerp, tilemap->time_up, tilemap->time_down);
        
        tilemap->endpoint :: Vector2.{ 0, -3 };
        if ui_append_to(tilemap) {
            ui_offset_handle(ui_id("offset"), tilemap->endpoint.(Vector2), true);
            ui_pop();
        }
        
        set_next_offset(tilemap, tilemap->endpoint.(Vector2) * lerp);
    }
}

