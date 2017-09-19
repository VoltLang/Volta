//T macro:import
module test;

import am = allocmap;

struct A = mixin am.AllocHashMap!(i32);

fn main() i32
{
	a: A;
	a.x = 32;
	return a.x - 32;
}
