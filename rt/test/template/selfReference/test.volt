module main;

struct S!(T) {
	x: T;

	fn copy() S {
		s: S;
		s.x = x;
		return s;
	}
}

struct Si = mixin S!i32;

fn main() i32 {
	i: Si;
	i.x = 12;
	j := i.copy();
	return j.x - 12;
}
