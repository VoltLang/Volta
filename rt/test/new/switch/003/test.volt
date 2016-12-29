// Final switches.
module test;

enum A
{
	B, C, D
}

fn main() i32
{
	final switch (A.B) {
	case A.B:
		return 0;
	case A.C:
		return 5;
	case A.D:
		return 7;
	}
}
