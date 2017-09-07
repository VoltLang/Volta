//T macro:expect-failure
//T check:cannot implicitly convert
module test;

fn main() i32
{
	aa: i32[string];
	aa = null;
	return 0;
}
