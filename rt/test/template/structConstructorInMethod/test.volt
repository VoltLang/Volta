module main;

struct S!(T) {
	x: T;

	this(x: T) {
		this.x = x;
	}

	fn copy() S {
		return S(x);
	}
}

struct Si = mixin S!i32;

fn main() i32 {
	i := Si(12);
	j := i.copy();
	return j.x - 12;
}
