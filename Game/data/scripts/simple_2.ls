
for members_of(orbiters) {
    cycle_time := random_float(2, 4);
    cycle_lerp := cycle_over_random(time, cycle_time, cycle_time, true, true);
    
    if ui_append_to(it) {
        ui_path_handle(path_0);
        ui_pop();
    }
    
    path_offset := get_offset(path_0, cycle_lerp);
    set_next_offset(it, path_offset);
}
