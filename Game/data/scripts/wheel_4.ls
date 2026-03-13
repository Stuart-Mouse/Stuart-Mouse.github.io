/*
    The design of this level is ot bring to the player's attention the idea that 
    many wheels may move either with or agianst the player, and this will make 
    quite a big difference as to how the level plays!
    
    When a wheel's direction of rotation is against the player, it feels a lot like you're on a treadmill,
    and movement becomes very staccato since you are fighting to move against the flow.
    
    On the contrary, when a wheel's direction is with the player, 
    they can make use of its momentum to make larger jumps, and the player's motions start to flow.
    
    In either case, it's a lot like moving through a stream of water.
    Most likely, the wheel section will be decorated as some sort of mill, 
    with large water wheels being part of both the decoration and the level design.
*/


chain_palette := palette_id("wood");

fireball_id := find_entity_template_index_by_name("Fireball");

for platform: members_of(wheel) {
    center := platform.position;
    set_next_offset(platform, .{});
    platform.scale.x = 0.5;
    
    platform->platform_width :: 1.5;//random_float(1, 2.5);
    
    platform->orbital_count :: 5;
    
    platform->radius :: 4.0;
    
    // cycle_lerp := cycle_over_random(time, 3, 7, true, true);
    platform->cycle_time :: 5.0;
    cycle_lerp := cycle_over(time, platform->cycle_time);
    if random_bool()  cycle_lerp = 1.0 - cycle_lerp;
    
    for 0..platform->orbital_count.(int)-1 {
        id := random_get();
        it_lerp := cycle_lerp + (it.(float) / platform->orbital_count.(int).(float));
        platform_position := center + circle(it_lerp, 0) * platform->radius.(float);
        
        immediate_platform(id, platform_position, .{ platform->platform_width.(float), 1 });
        do_movement_visualizer_chain(center, platform_position, chain_palette, .{0.25,0.25,0.25,1});
    }
}

