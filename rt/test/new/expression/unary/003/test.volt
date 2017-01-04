module test;

struct S {
	x: i32[];
}

fn main() i32
{
	s: S;
	s.x = new int[](12);
	s.x[0] = 3;
	b := new s.x[0 .. $];
	b[0] = 1;
	return s.x[0] + b[0] - 4;
}

