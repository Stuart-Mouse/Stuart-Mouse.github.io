
pi  := 3.14159;
tau := 2 * pi;

cycle_time :: 4?;

// working, but not very useful in current state. 
// would be better to use a directive that maintains its own 'static' value, 
// so we can just pass any old value into the proc but also hold internal state. 
// Xfloat("cycle time", cycle_time);

cycle := fmod(time, cycle_time) / cycle_time;
offset := sin(tau * cycle);

platform_range :: Vector2.{ 3, 1 }?;
platform.offset_next = platform.root_offset;
platform.offset_next += .{ sin(tau * cycle),  cos(tau * 2 * cycle) } * platform_range;


if has_flag(red_guy, Entity_Flags.ON_GROUND) {
    if fmod(time, 1) < 0.1 {
        red_guy.base.velocity.y -= 10.0 / updates_per_second;
    }
    if red_guy.position.x < player.position.x {
        red_guy.walk_direction = .R;
    }
    if red_guy.position.x > player.position.x {
        red_guy.walk_direction = .L;
    }
}


