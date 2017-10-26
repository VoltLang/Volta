//T macro:expect-failure
//T check:12:8: error: enum 'A' does not define 'C'.
module test;

enum A
{
	B
}

fn main() i32
{
	return A.C;
}
