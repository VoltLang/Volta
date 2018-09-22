//T macro:expect-failure
//T check:.default on non-type expression
module test;

alias A = i32;

fn main() i32
{
	a: A;
	return a.default;
}
