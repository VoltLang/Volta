//T macro:abi
//T requires:win64
//T check:void @foo(%DviZv*)
module test;

extern (C) fn foo(dgt: dg(i32))
{
	dgt(32);
}

fn main() i32
{
	x: i32;
	fn bar(y: i32)
	{
		x = y;
	}
	foo(bar);
	return x;
}
