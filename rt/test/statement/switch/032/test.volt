module test;

fn main() i32
{
	str := [1, 2, 3];
	switch (str) {
	case [1, 2, 3]:
		return 0;
	case [1, 2, 1]:
		return 2;
	default:
		return 1;
	}
}
