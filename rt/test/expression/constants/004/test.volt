//T macro:expect-failure
//T check:cannot implicitly convert
module test;

fn main() i32
{
	a: i8 = -129;
	return cast(i32)a + 129;
}
