// Test string literals.
module test;


fn func(val: i32[]) i32
{
	return val[1];
}

fn main() i32
{
	return (func([41, 42, 43]) == 42) ? 0 : 1;
}
