//T macro:expect-failure
module test;

struct S {
	y: Y;
	b: i32;
}

struct Y {
	x: i32;
}

fn main() i32
{
	s: S;
	s.b = 7;
	s.y.x = 3;
	x: i32;
	with (s.y) with (s) {
		return b + x;
	}
}

