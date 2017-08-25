//T macro:expect-failure
//T check:cannot implicitly convert
// Big data types should have big maxes.
module test;

fn main() i32
{
	return u64.max;
}
