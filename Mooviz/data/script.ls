#declare("planet");
#declare("moon1");
#declare("moon2");
#declare("moon3");

// some basic constants
pi  := 3.14159;
tau := 2 * pi;

// the entire state of the visualization is evaluated discretely
// so we use fmod on the global time to create cycles in movement
// try playing with the cycle time to speed up or slow down the entire scene
cycle_time := 8;

cycle := fmod(time, cycle_time) / cycle_time;
radius := 0.25;

planet.position = Vector2.{ 0.5, 0.5 } + ellipse(cycle, 2, 1, 3/8) * Vector2.{ radius/2, radius };
planet.rotation = cos(cycle * tau) * 2;
planet.size.x = 0.05;

// render 10 tail points following the planet
for 1..10 {
    cycle_offset := it.(float) * 0.05;
    lerp := cycle - cycle_offset;
    trail := Vector2.{ 0.5, 0.5 } + ellipse(lerp, 2, 1, 3/8) * Vector2.{ radius/2, radius };
    draw_square(trail, 0.01, cos(lerp * tau) * 2, planet.color);
}

// the smaller planets orbit on a subcycle of the main planet's cycle
// here you can adjust the speed/radius of the moons' orbits 
// and the rotation of their orbits around the main planet
subcycle := cycle * 4;
orbit_rotation_cycle_time := 16;
orbit_radius := radius / 3;

orbit_rotation := fmod(time, orbit_rotation_cycle_time) / orbit_rotation_cycle_time * tau;

moon1_orbit := circle(subcycle, 1/3);
moon1.position = planet.position + rotate(moon1_orbit * orbit_radius, orbit_rotation);
moon1.size.x   = planet.size.x * 0.75;
moon1.rotation = moon1_orbit.x * -2;

moon1.color.r = 0.5 + 0.5 * moon1_orbit.x;
moon1.color.g = 0.5;
moon1.color.b = 0.5;
moon2_orbit := circle(subcycle + 3/8, 2/3);

moon2.position = planet.position + rotate(moon2_orbit * orbit_radius, orbit_rotation);
moon2.size.x   = planet.size.x * 0.6;
moon2.rotation = moon2_orbit.x * -2;

moon2.color.r = 0.5;
moon2.color.g = 0.5;
moon2.color.b = 0.5 + 0.5 * moon2_orbit.x;

moon3_orbit := circle(subcycle + 6/8, 2/3);
moon3.position = planet.position + rotate(moon3_orbit * orbit_radius, orbit_rotation);
moon3.size.x   = planet.size.x * 0.45;
moon3.rotation = moon3_orbit.x * -2;

moon3.color.r = 0.5;
moon3.color.g = 0.5 + 0.5 * moon3_orbit.x;
moon3.color.b = 0.5;
