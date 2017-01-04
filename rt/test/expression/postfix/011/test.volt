// Reordering arguments with labels.
module test;

@label fn sub(a: i32, b: i32) i32
{
	return a - b;
}

fn main() i32
{
	return sub(b:1, a:3) - 2;
}
