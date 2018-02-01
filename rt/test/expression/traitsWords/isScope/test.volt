module main;

fn aFunction!(T)() i32
{
	static if (is(T == @isScope)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = scope i32[];

fn a = mixin aFunction!(A);
fn b = mixin aFunction!(i32[string]);

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
