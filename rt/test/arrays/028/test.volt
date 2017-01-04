//T default:no
//T macro:expect-failure
// Invalid allocation with new auto.
module test;

fn main() i32
{
	x: i32[] = new auto(3);

	return 1;
}
