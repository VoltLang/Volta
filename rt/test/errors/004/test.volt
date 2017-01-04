//T default:no
//T macro:expect-failure
//T check:13:9: error: enum 'A' does not define 'C'.
module test;

enum A
{
	B
}

fn main() i32
{
	return A.C;
}
