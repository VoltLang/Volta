//T macro:expect-failure
//T check:neither ref nor out
module test;

fn flubber(x: i32) i32
{
	return x;
}

fn main() i32
{
	integer := 6;
	return flubber(ref integer);
}
