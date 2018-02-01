//T macro:expect-failure
//T check:expected constant expression that evaluates to a bool
module main;

enum A = 0;

fn a() i32
{
	static if (A) {
		return 3;
	} else {
		return 7;
	}
}

fn main() i32
{
	return a() - 7;
}
