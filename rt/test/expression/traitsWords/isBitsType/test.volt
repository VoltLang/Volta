module main;

fn aFunction!(T)() i32
{
	static if (is(T == @isBitsType)) {
		return 2;
	} else {
		return 1;
	}
}

fn a = mixin aFunction!(f32);
fn b = mixin aFunction!(bool);

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
