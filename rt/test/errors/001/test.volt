//T default:no
//T macro:expect-failure
//T check:9:9: error: unidentified identifier 'y'.
module test;

fn main() i32
{
	x: i32;
	return y;
}

