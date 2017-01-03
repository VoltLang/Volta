// Basic function call & this test.
module test;


struct Test
{
	val: i32;

	fn setVal(inVal: i32)
	{
		val = inVal;
	}
}

fn main() i32
{
	test: Test;
	test.setVal(42);
	return test.val - 42;
}
