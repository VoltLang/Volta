//T default:no
//T macro:expect-failure
//T check:expected only one argument
module test;

fn main() i32
{
	a := i32(12);
	b := new i32(4, 2);
	return a + *b;
}
