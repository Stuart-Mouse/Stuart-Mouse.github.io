
pi  := 3.14159;
tau := 2 * pi;

cycle_time :: 4?;

// working, but not very useful in current state. 
// would be better to usea directive that maintains its own 'static' value, 
// so we can just pass any old value into the proc but also hold internal state. 
// Xfloat("cycle time", cycle_time);    

cycle := fmod(time, cycle_time) / cycle_time;

platform_range :: Vector2.{ 3, 1 }?;
platform.offset_next = platform.root_offset;
platform.offset_next += .{ sin(tau * cycle),  cos(tau * 2 * cycle) } * platform_range;

// rot_cycle := fmod(cycle * 3 + 0.5, 1);
platform.rotation_next = platform.base_rotation + sin(tau * cycle) * 15;



leapfrog_range :: Vector2.{ 2, 1 }?;

leapfrog_1.offset_next = leapfrog_1.root_offset;
leapfrog_1.offset_next += .{ sin(tau * cycle),  cos(tau * cycle) } * leapfrog_range;

leapfrog_2.offset_next = leapfrog_2.root_offset;
leapfrog_2.offset_next -= .{ sin(tau * cycle),  cos(tau * cycle) } * leapfrog_range;


