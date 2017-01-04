//T default:no
//T macro:expect-failure
// Invalid array allocation.
module test;

fn main() i32
{
	a: i32[];
	// array allocation, no concatenation (array) allowed.
	b: i32[] = new i32[](3, a);

	return 0;
}
