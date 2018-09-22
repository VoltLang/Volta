module test;

struct S
{
	x: i32;
	union _u {
		y: i32;
		z: i64;
	}
	u: _u;
}

fn main() i32
{
	s: S;
	s.x = 1;
	s.u.y = 12;
	s = S.default;
	return cast(i32)(s.x + s.u.y + s.u.z);
}
