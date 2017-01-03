// Basic struct write test.
module test;


struct Test
{
	val: i32;
}

fn main() i32
{
	test: Test;;
	test.val = 42;
	return test.val - 42;
}
