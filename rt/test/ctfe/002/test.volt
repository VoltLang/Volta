//T macro:expect-failure
//T check:7:
module test;

fn main() i32
{
	fn nested() i32 { return 7; }
	return #run nested();
}
