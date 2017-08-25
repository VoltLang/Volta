//T macro:expect-failure
//T check:scope may not be returned
module test;

fn foo() scope dg() i32
{
	fn func() i32 { return 13; }
	dgt: scope dg() i32 = func;
	return dgt;
}

fn main() i32
{
	dgt := foo();
	return dgt();
}
