//T default:no
//T macro:expect-failure
//T has-passed:no
module test;

fn main() i32
{
	str := [1, 2, 3];
	switch (str) {
	case [1, 2, 3]:
		return 1;
	case [1, 2, 3]:
		return 2;
	default:
		return 0;
	}
}
