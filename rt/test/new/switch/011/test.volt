// Switch over array literals.
module test;

fn main() i32
{
	foo: i32[] = [3, 3];
	switch (foo) {
	case [1, 1]:
		return 1;
	case [2, 2]:
		return 2;
	case [3, 3]:
		return 0;
	default:
		return 4;
	}
}
