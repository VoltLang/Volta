module test;

fn case1(dgt: dg(string), dgt2: dg() i32)
{
	dgt("llo");
	if (dgt2() == 2) {
		dgt("ab");
	}
}

fn main() i32
{
	x: i32;
	fn f1(s: string) {
		x += cast(int)s.length;
	}
	fn f2() i32 {
		return 2;
	}

	case1(f1, f2);

	return x - 5;
}
