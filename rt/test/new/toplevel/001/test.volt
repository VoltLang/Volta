module test;

global x: i32;

global this()
{
	x = 0;
	return;
}

global ~this()
{
	x = 2;
	return;
}

fn main() i32
{
	return x;
}

