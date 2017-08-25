//T macro:expect-failure
// Final switches failing test.
module test;

enum A
{
	B, C, D
}

fn main() i32
{
	final switch (A.B) {
	case A.B:
		return 1;
	case A.C:
		return 5;
	}
}
