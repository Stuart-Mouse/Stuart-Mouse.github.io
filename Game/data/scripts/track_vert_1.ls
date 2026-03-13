
player_y_offset := player.position.y - level.player_debug_spawn.y;

for tilemap: tracking_1, tracking_2 {
    tilemap->offset_scalar :: 0.5;
    set_next_offset(tilemap, .{ 0, player_y_offset * tilemap->offset_scalar.(float) });
}
