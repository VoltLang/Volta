//T macro:expect-failure
//T check:22:0: error: 'PiDoubler' is not a template definition
module main;

struct ValueStore!(T, V: T)
{
	fn get() T
	{
		return V;
	}
}

struct ValueDoubler!(T, V: T)
{
	fn get() T
	{
		return cast(T)(V * 2);
	}
}

struct FortyStore = mixin ValueStore!(i32, 40);
struct PiDoubler  = mixin PiDoubler!(f64, 3.1415926538);

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
