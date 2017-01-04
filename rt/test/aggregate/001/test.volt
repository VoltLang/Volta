// Basic struct read test.
module test;


struct Test
{
	val: i32;
}

fn main() i32
{
	test: Test;
	return test.val;
}
