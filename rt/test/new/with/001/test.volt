module test;

struct S {
	y: Y;
}

struct Y {
	x: i32;
}

fn main() i32
{
	s: S;
	s.y.x = 7;
	with (s.y) {
		return x - 7;
	}
}

