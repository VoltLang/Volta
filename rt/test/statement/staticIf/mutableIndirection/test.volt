module main;

fn aFunction!(T)() i32
{
	static if (typeid(T).mutableIndirection) {
		return 1;
	} else {
		return 2;
	}
}

fn a = mixin aFunction!(i32);
fn b = mixin aFunction!(i32*);

fn main() i32
{
	if (a() != 2) {
		return 1;
	}
	if (b() != 1) {
		return 2;
	}
	return 0;
}
