// Basic struct function passing test.
module test;


struct Test
{
	val: i32;
	otherVal: i32;
}

fn func(t: Test) i32
{
	return t.otherVal;
}

fn main() i32
{
	test: Test;
	test.val = 42;
	return func(test);
}
