//T macro:expect-failure
//T check:8:8: error: unidentified identifier 'y'.
module test;

fn main() i32
{
	x: i32;
	return y;
}

