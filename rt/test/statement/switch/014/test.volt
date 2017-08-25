//T macro:expect-failure
// Switch case array in array literal failure test.
module test;

fn main() i32
{
	foo: i64[][] = [[cast(i64)3, 3]];

	switch (foo) {
	case [[cast(i64)3, 3]]:
		return 3;
	default:
		return 4;
	}
}
