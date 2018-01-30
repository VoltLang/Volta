//T macro:import
module main;

import storetest;

fn getGetter!(T, K)(getter: K) T
{
	return getter.get();
}

fn fortyGetter = mixin getGetter!(i32, FortyStore);
fn piDoubler   = mixin getGetter!(f64, PiDoubler);

fn main() i32
{
	fs: FortyStore;
	if (fortyGetter(fs) != 40) {
		return 1;
	}
	pd: PiDoubler;
	if (piDoubler(pd) <= 6.0 || piDoubler(pd) >= 6.5) {
		return 2;
	}
	return 0;
}
