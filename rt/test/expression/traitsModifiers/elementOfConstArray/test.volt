module main;

fn aFunction!(T)() i32
{
	static if (is(@elementOf!T == @isConst)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = const(char[]);
fn a = mixin aFunction!(A);

fn main() i32
{
	if (a() != 2) {
		return 1;
	}
	return 0;
}
