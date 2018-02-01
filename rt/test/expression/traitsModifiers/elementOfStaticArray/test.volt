module main;

fn aFunction!(T)() i32
{
	static if (is(@elementOf!T == char)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = char[512];
fn a = mixin aFunction!(A);

fn main() i32
{
	if (a() != 2) {
		return 1;
	}
	return 0;
}
