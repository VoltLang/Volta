//T macro:expect-failure
//T check:cannot implicitly convert
// Mismatched types.
module test;


fn main() i32
{
	return true ? 3 : "foo";
}
