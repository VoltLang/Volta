//T macro:expect-failure
//T check:expression has no type
module test;

import core.object;

fn main() i32
{
	typeof(core) foo;
	return 0;
}
