module test;

fn frimulize(a: i32, b: i32) i32
{
	return a + b;
}

fn frobulate(a: i32) i32
{
	return frimulize(12, a * 2) - 24;
}

fn main() i32
{
	return #run frobulate(6);
}
