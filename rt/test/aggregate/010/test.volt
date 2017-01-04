// Basic delegate creation.
module test;


struct Test
{
	val: i32;

	fn setVal(inVal: i32)
	{
		this.val = inVal;
	}

	fn addVal(add: i32)
	{
		val += add;
	}
}

fn main() i32
{
	test: Test;

	dgt: dg(i32) = test.setVal;
	dgt(20);

	dgt = test.addVal;
	dgt(22);

	return test.val - 42;
}
