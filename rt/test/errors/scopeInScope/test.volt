//T macro:expect-failure
//T check:scope statements inside of scope
module test;

fn alpha() i32
{
	scope (exit) scope (exit) a := 2;
	return 2;
}

fn main() i32
{
	return alpha();
}
