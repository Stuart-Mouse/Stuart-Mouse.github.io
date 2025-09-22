pi  := 3.14159;
tau := 2.0 * pi;

fireball_id := find_entity_template_index_by_name("Fireball");

pendulums := entity_group("pendulums");
for pendulums {
    pendulum_distance     := random_float(4, 6);
    pendulum_cycle_time   := pendulum_distance * 0.75;
    pendulum_cycle_offset := random_float(0, 1);
    pendulum_angle        := random_float(5, 10) / 180.0  * pi;
    
    cycle_lerp := cycle_over(time, pendulum_cycle_time) + pendulum_cycle_offset;
    
    offset := pendulum(cycle_lerp, pendulum_distance, pendulum_angle);
    
    set_next_offset(it, offset);
}
