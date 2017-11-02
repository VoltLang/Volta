//T macro:expect-failure
//T check:got an expression where
module test;

fn main() i32
{
	xyz := 32;
	y := new xyz;
	return 0;
}
