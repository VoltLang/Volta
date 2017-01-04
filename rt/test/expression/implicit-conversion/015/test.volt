module test;

global x: scope i32*;

fn foo(z: scope i32*)
{
}

fn main() i32
{
	y: scope i32* = x;
	foo(x);
	return 0;
}

