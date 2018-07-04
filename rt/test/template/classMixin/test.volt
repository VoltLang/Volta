//T macro:import
module main;

import contrived;

enum V = 6;

class MixinContrived   = mixin Contrived!i32;
class RegularContrived =       Contrived!i32;

fn main() i32
{
	a := new MixinContrived();
	b := new RegularContrived();
	return a.foo() + b.foo() - 18;
}
