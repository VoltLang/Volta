//T macro:expect-failure
//T check:return statements inside of scope
module test;

fn alpha() i32
{
	scope (exit) return;
	return 2;
}

fn main() i32
{
	return alpha();
}
