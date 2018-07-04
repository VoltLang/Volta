//T macro:import
module main;

import eyeballs;

enum V = 7;

union IntegerEyeballsA =       Eyeballs!i32;
union IntegerEyeballsB = mixin Eyeballs!i32;

fn main() i32
{
	return IntegerEyeballsA.a + IntegerEyeballsB.a - 12;
}
