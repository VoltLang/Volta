//T macro:expect-failure
//T check:symbol 'x' redefinition
module test;

class Parent
{
	x: i32;
}

class Child : Parent
{
	x: i32;
}

fn main() i32
{
	return 0;
}
