module test;

fn over(i: i32) i32
{
	switch (i) {
	case 7:
	case 0: return 7;
	case 1: return 8;
	default: return 0;
	}
}

fn main() i32
{
	return over(8000);
}
