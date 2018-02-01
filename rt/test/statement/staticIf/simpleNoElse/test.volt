module main;

enum A = 32;

fn a() i32
{
	static if (A == 31) {
		return 3;
	}
	return 7;
}

fn main() i32
{
	return a() - 7;
}
